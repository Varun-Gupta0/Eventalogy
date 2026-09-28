import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { createAgentTask, updateAgentTaskStatus } from "../services/agent_task_service";
import { executeTool } from "../utils/tool_executor";
import { createEnquiryTool, createBookingTool, createAllocationTool } from "../tools/bookings";
import type { StateType } from "../graph/state";

const BookingOutputSchema = z.object({
  createdEnquiryIds: z.array(z.string()),
  createdBookingIds: z.array(z.string()),
  createdAllocationIds: z.array(z.string()),
  summary: z.string(),
  skippedItems: z.array(z.string()),
});

export async function bookingAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();

  // ── HARD GATE: verify approval ─────────────────────────────────────────────
  // Bookings CANNOT be created without explicit user approval.
  if (state.approvalStatus !== "approved") {
    await logAgentAction(state.workflowId, "booking_agent", "blocked_no_approval", "error", { approvalStatus: state.approvalStatus });
    return {
      workflowStatus: "error",
      lastError: "Booking agent blocked: approvalStatus is not 'approved'. Bookings cannot be created without explicit user approval.",
      agentHistory: [{ agent: "booking_agent", stage: "booking", status: "error", startedAt: new Date(startTime).toISOString(), notes: "Blocked - approval not granted" }],
    };
  }

  // Idempotency: skip if bookings already created (retry protection)
  if ((state.createdBookingIds ?? []).length > 0) {
    await logAgentAction(state.workflowId, "booking_agent", "idempotency_skip", "success", { existingBookings: state.createdBookingIds });
    return { currentAgent: "orchestrator_agent", currentStage: "communication", completedTasks: ["booking_agent"] };
  }

  await logAgentAction(state.workflowId, "booking_agent", "start", "running");
  const taskId = await createAgentTask(state.workflowId, "booking_agent", "running", { approvedBy: state.userId }, false);

  const tools = [createEnquiryTool, createBookingTool, createAllocationTool];
  const llm = getLLMProvider({ temperature: 0.0 }).bindTools(tools);

  const approval = state.pendingApprovals?.[0];
  const dateStr = state.eventRequirements.dateStr ?? new Date().toISOString().split("T")[0];
  const endTimeStr = new Date(new Date(dateStr).getTime() + 8 * 60 * 60 * 1000).toISOString();

  const systemPrompt = `You are the Eventology Booking Agent.

User approval has been confirmed. Your job is to create booking records in Firestore.

APPROVAL VERIFIED:
- Approved venue: ${approval?.recommendedVenueId ?? "none"}
- Approved vendors: ${(approval?.recommendedVendors ?? []).map((v: any) => `${v.vendorId} (${v.serviceCategory})`).join(", ")}
- Event date: ${dateStr}
- Customer userId: ${state.userId}
- Event ID: ${state.eventId ?? "none"}

Steps to execute:
1. For each approved vendor+service: first use create_enquiry, then create_booking
2. If a venue is selected, use create_allocation to link it to the event
3. For each vendor, use create_allocation to link them
4. Record all created IDs carefully

Rules:
- Use userId ${state.userId} as customerId
- Use eventId ${state.eventId ?? "pending"} for all records
- assignedBy for allocations: ${state.workflowId}
- Do NOT create duplicate records
- Skip items where required data is missing rather than creating invalid records

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_booking_results" tool to output the final results. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Create bookings for: Venue=${approval?.recommendedVenueId}, Vendors=${JSON.stringify(approval?.recommendedVendors)}, Date=${dateStr}`),
  ];

  try {
    const maxIter = Math.max(12, (approval?.recommendedVendors?.length ?? 0) * 3 + 4);
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.0 }).bindTools([
      ...tools,
      {
        name: "submit_booking_results",
        description: "MUST be called to finalize your response. Call this when you have finished creating all necessary bookings and allocations.",
        schema: BookingOutputSchema,
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
        if (tc.name === "submit_booking_results") {
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
        createdEnquiryIds: [],
        createdBookingIds: [],
        createdAllocationIds: [],
        summary: fallbackText || "Agent failed to output structured booking results.",
        skippedItems: ["Failed to format results correctly"]
      };
    }

    const output = finalExtraction;

    await updateAgentTaskStatus(taskId, "completed", output);
    await logAgentAction(state.workflowId, "booking_agent", "complete", "success", { enquiries: output.createdEnquiryIds.length, bookings: output.createdBookingIds.length, durationMs: Date.now() - startTime });

    return {
      createdEnquiryIds: output.createdEnquiryIds,
      createdBookingIds: output.createdBookingIds,
      createdAllocationIds: output.createdAllocationIds,
      currentAgent: "orchestrator_agent",
      currentStage: "booking",
      workflowStatus: "active",
      agentHistory: [{ agent: "booking_agent", stage: "booking", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Created ${output.createdBookingIds.length} bookings, ${output.createdEnquiryIds.length} enquiries, ${output.createdAllocationIds.length} allocations` }],
      completedTasks: ["booking_agent"],
    };
  } catch (err: any) {
    await updateAgentTaskStatus(taskId, "error", undefined, err.message);
    await logAgentAction(state.workflowId, "booking_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["booking_agent"],
      lastError: `Booking agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "booking_agent", stage: "booking", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
