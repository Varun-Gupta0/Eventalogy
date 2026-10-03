import { z } from "zod";
import { SystemMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { getEventTypesTool, getLocationsTool } from "../tools/services";
import type { StateType } from "../graph/state";

const IntakeOutputSchema = z.object({
  extractedRequirements: z.object({
    eventType: z.string().optional(),
    guestCount: z.number().optional(),
    location: z.string().optional(),
    dateStr: z.string().optional(),
    budgetStr: z.string().optional(),
    preferences: z.array(z.string()).optional(),
    constraints: z.array(z.string()).optional(),
  }),
  missingInformation: z.array(z.string()),
  nextQuestion: z.string().optional(),
  isComplete: z.boolean(),
  confidence: z.number().min(0).max(1),
});

export async function eventIntakeAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "event_intake_agent", "start", "running");

  const tools = [getEventTypesTool, getLocationsTool];
  const llm = getLLMProvider({ temperature: 0.1 });

  const systemPrompt = `You are the Eventology Event Intake Agent.

Your goal is to extract structured event requirements from the user's natural language messages.

You have access to tools to fetch valid event types and supported locations from the Eventology database.
Use them to validate what the user mentions and provide accurate suggestions.

CRITICAL: When you have finished gathering information, OR when you need to ask the user a follow-up question, you MUST call the "submit_intake_results" tool. You MUST NOT respond with plain text.

Critical requirements to extract:
- Event Type (must match a real event type in the system)
- Location / City (must be a supported location in the system)
- Guest Count (number of attendees)
- Date / Date Range (when is the event)
- Budget (approximate budget in INR, optional but helpful)
- Preferences (e.g., outdoor, vegetarian, specific theme)
- Constraints (e.g., no alcohol, wheelchair accessible)

Rules:
- Do NOT assume or invent data not stated by the user
- Use tools to validate event types and locations
- Set isComplete = true ONLY when you have: eventType, location, guestCount, and dateStr
- Always provide a nextQuestion if isComplete is false
- You MUST call submit_intake_results to communicate with the user.

Current known requirements:
${JSON.stringify(state.eventRequirements, null, 2)}`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    ...state.conversationHistory,
  ];

  try {
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;
    
    // Create the model binding that includes the submit tool
    const modelWithTools = llm.bindTools([
      ...tools,
      {
        name: "submit_intake_results",
        description: "MUST be called to finalize your response. Call this when you have extracted requirements or need to ask the user a follow-up question.",
        schema: IntakeOutputSchema,
      }
    ]);

    while (iterations < 4) {
      const response = await modelWithTools.invoke(messages) as AIMessage;
      messages.push(response);
      
      // If the model somehow returns plain text instead of tool calls, save it as a fallback
      if (response.content && typeof response.content === 'string') {
        fallbackText = response.content;
      }
      
      if (!response.tool_calls?.length) {
        break; // Stop if the model refuses to call tools
      }
      
      let extractionFound = false;
      
      for (const tc of response.tool_calls) {
        if (tc.name === "submit_intake_results") {
          finalExtraction = tc.args;
          extractionFound = true;
          break; // Stop processing other tools if we got the final result
        } else if (tc.name === "get_event_types" || tc.name === "get_locations") {
          // Execute normal tools
          const toolToRun = tools.find(t => t.name === tc.name);
          if (toolToRun) {
            const result = await executeTool([toolToRun] as any, tc);
            messages.push(new ToolMessage({ content: result, tool_call_id: tc.id! }));
          }
        }
      }
      
      if (extractionFound) break;
      iterations++;
    }

    // If the model completely ignored the submit tool and just gave text, fallback gracefully
    if (!finalExtraction) {
      let parsedQuestion = fallbackText;
      if (fallbackText && fallbackText.trim().startsWith('{')) {
        try {
          const parsed = JSON.parse(fallbackText);
          if (parsed.nextQuestion) parsedQuestion = parsed.nextQuestion;
        } catch (e) {
          // ignore parse errors
        }
      }
      finalExtraction = {
        extractedRequirements: state.eventRequirements || {},
        missingInformation: ["Unknown (fallback)"],
        nextQuestion: parsedQuestion || "Could you provide more details?",
        isComplete: false,
        confidence: 0,
      };
    }

    await logAgentAction(state.workflowId, "event_intake_agent", "complete", "success", { isComplete: finalExtraction.isComplete, confidence: finalExtraction.confidence, durationMs: Date.now() - startTime });

    return {
      eventRequirements: finalExtraction.extractedRequirements,
      missingInformation: finalExtraction.missingInformation,
      pendingQuestions: finalExtraction.nextQuestion ? [finalExtraction.nextQuestion] : [],
      conversationHistory: finalExtraction.nextQuestion ? [new AIMessage(finalExtraction.nextQuestion)] : [],
      intakeComplete: finalExtraction.isComplete,
      workflowStatus: finalExtraction.isComplete ? "active" : "pending_user",
      currentAgent: "orchestrator_agent",
      agentHistory: [{ agent: "event_intake_agent", stage: "intake", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: finalExtraction.isComplete ? "Requirements complete" : `Missing: ${finalExtraction.missingInformation.join(", ")}` }],
      completedTasks: finalExtraction.isComplete ? ["event_intake_agent"] : [],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "event_intake_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["event_intake_agent"],
      lastError: `Intake error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "event_intake_agent", stage: "intake", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
