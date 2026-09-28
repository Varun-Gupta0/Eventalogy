import { z } from "zod";
import { StateType } from "../../graph/state";
import { getLLMProvider } from "../../llm/provider";
import { SystemMessage } from "@langchain/core/messages";
import { logAgentAction } from "../../services/agent_log_service";

const IntakeOutputSchema = z.object({
  extractedRequirements: z.object({
    eventType: z.string().optional(),
    guestCount: z.number().optional(),
    location: z.string().optional(),
    dateStr: z.string().optional(),
    budgetStr: z.string().optional(),
    preferences: z.array(z.string()).optional(),
    constraints: z.array(z.string()).optional(),
  }).describe("Currently known event requirements extracted from conversation. Update with new info."),
  missingInformation: z.array(z.string()).describe("List of critical information missing for planning (e.g., guest count, location, type, budget, date)"),
  nextQuestion: z.string().optional().describe("The best natural language conversational question to ask the user next to gather missing information"),
  isComplete: z.boolean().describe("True if sufficient basic requirements are gathered to begin event planning"),
  confidence: z.number().min(0).max(1).describe("Confidence in extraction")
});

export async function eventIntakeNode(state: StateType): Promise<Partial<StateType>> {
  await logAgentAction(state.workflowId, "event_intake", "start_extraction", "running");
  
  const llm = getLLMProvider({ temperature: 0.1 });
  const structuredLlm = llm.withStructuredOutput(IntakeOutputSchema, { name: "event_intake" });

  const systemPrompt = `You are the Eventology Event Intake Agent.
Your goal is to extract event requirements from the user's natural language conversation.
You should determine what is known and what is missing.
Critical requirements typically include: Event Type, Location, Guest Count, Date/Time, and Budget.
Do not make assumptions. If something is unknown, leave it empty in the extractedRequirements and add it to missingInformation.
If information is missing, provide a friendly nextQuestion to ask the user.
Set isComplete to true ONLY if you have enough information to create a basic event plan (typically need at least Type, Guest Count, Location).

Current extracted state:
${JSON.stringify(state.eventRequirements, null, 2)}`;

  const messages = [
    new SystemMessage(systemPrompt),
    ...state.conversationHistory
  ];

  try {
    const result = await structuredLlm.invoke(messages);

    await logAgentAction(state.workflowId, "event_intake", "complete_extraction", "success", {
      isComplete: result.isComplete,
      missingInformation: result.missingInformation,
      confidence: result.confidence
    });

    return {
      eventRequirements: result.extractedRequirements,
      missingInformation: result.missingInformation,
      pendingQuestions: result.nextQuestion ? [result.nextQuestion] : [],
      intakeComplete: result.isComplete,
      workflowStatus: result.isComplete ? "active" : "pending_user",
    };
  } catch (error: any) {
    await logAgentAction(state.workflowId, "event_intake", "extraction_failed", "error", { error: error.message });
    return {
      lastError: `Intake Error: ${error.message}`,
      workflowStatus: "error"
    };
  }
}
