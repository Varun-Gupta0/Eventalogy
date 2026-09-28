import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { createNotificationTool } from "../tools/bookings";
import type { StateType } from "../graph/state";

const CommOutputSchema = z.object({
  createdNotificationIds: z.array(z.string()),
  summary: z.string(),
});

export async function communicationAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "communication_agent", "start", "running");

  const tools = [createNotificationTool];
  const llm = getLLMProvider({ temperature: 0.3 }).bindTools(tools);

  const venueName = (state.candidateVenues ?? []).find(v => v.venueId === state.selectedVenueId)?.name ?? "Selected venue";

  const systemPrompt = `You are the Eventology Communication Agent.

Bookings have been created. Your job is to generate and save in-app notifications.
You do NOT send external emails or SMS - you create notification records in Firestore.

Created records:
- Enquiry IDs: ${JSON.stringify(state.createdEnquiryIds)}
- Booking IDs: ${JSON.stringify(state.createdBookingIds)}

Customer userId: ${state.userId}
Event: ${state.eventRequirements.eventType ?? "Event"} on ${state.eventRequirements.dateStr ?? "TBD"}
Venue: ${venueName}

Notifications to create:
1. Booking confirmation for customer (userId: ${state.userId}), type: booking_confirmed
2. For each vendor in ${JSON.stringify(state.selectedVendorIds ?? [])}, type: vendor_booking_received

Write clear, professional notification messages. Include relevant IDs in metadata.

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_communication_results" tool to output the final results. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Create notifications for all bookings. Customer: ${state.userId}. Vendors: ${state.selectedVendorIds?.join(", ")}`),
  ];

  try {
    const maxIter = Math.max(6, (state.selectedVendorIds?.length ?? 0) + 3);
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.3 }).bindTools([
      ...tools,
      {
        name: "submit_communication_results",
        description: "MUST be called to finalize your response. Call this when you have finished creating all notifications.",
        schema: CommOutputSchema,
      }
    ]);

    while (iterations < maxIter) {
      const response = await modelWithTools.invoke(messages) as AIMessage;
      messages.push(response);
      
      if (response.content && typeof response.content === 'string') {
        fallbackText = response.content;
      }
      
      if (!response.tool_calls?.length) break;
      
      let extractionFound = false;
      
      for (const tc of response.tool_calls) {
        if (tc.name === "submit_communication_results") {
          finalExtraction = tc.args;
          extractionFound = true;
          break;
        } else {
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

    if (!finalExtraction) {
      finalExtraction = {
        createdNotificationIds: [],
        summary: fallbackText || "Agent failed to output structured communication results.",
      };
    }

    const output = finalExtraction;

    await logAgentAction(state.workflowId, "communication_agent", "complete", "success", { notificationCount: output.createdNotificationIds.length, durationMs: Date.now() - startTime });

    return {
      currentAgent: "__end__",
      currentStage: "completed",
      workflowStatus: "completed",
      agentHistory: [{ agent: "communication_agent", stage: "communication", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Created ${output.createdNotificationIds.length} notifications. ${output.summary}` }],
      completedTasks: ["communication_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "communication_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["communication_agent"],
      currentStage: "completed",
      workflowStatus: "error", // Changed from "completed" to "error" to properly flag failure
      retryCount: (state.retryCount ?? 0) + 1,
      lastError: `Communication agent error: ${err.message}`,
      agentHistory: [{ agent: "communication_agent", stage: "communication", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
