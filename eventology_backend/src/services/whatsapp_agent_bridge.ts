import { v4 as uuidv4 } from "uuid";
import { HumanMessage } from "@langchain/core/messages";
import { Command } from "@langchain/langgraph";
import { eventologyAgentApp } from "../graph";
import { setIdentityConversation } from "./whatsapp_identity_service";
import { db } from "../config/firebase";

interface InvokeResult {
  responseText: string;
  conversationId: string;
  hasPendingApproval: boolean;
  approvalSummary?: string;
  approvalTotalCost?: number;
  isInterrupted: boolean;
}

/**
 * Invoke the existing LangGraph agent on behalf of a WhatsApp user.
 * This is the bridge between WhatsApp and the existing agent runtime.
 *
 * IMPORTANT: This function runs server-side with a trusted userId.
 * It does NOT use Firebase ID Tokens — the identity has already been
 * verified via the whatsapp_identities mapping.
 */
export async function invokeAgentForWhatsApp(
  userId: string,
  waId: string,
  message: string,
  existingConversationId: string | null
): Promise<InvokeResult> {
  const isNew = !existingConversationId;
  const conversationId = existingConversationId ?? uuidv4();
  const config = { configurable: { thread_id: conversationId } };

  let initialState: Partial<any>;

  if (isNew) {
    initialState = {
      workflowId: conversationId,
      conversationId,
      userId,
      eventId: null,
      currentAgent: "event_intake_agent",
      currentStage: "intake",
      userMessage: message,
      conversationHistory: [new HumanMessage(message)],
      eventRequirements: {},
      missingInformation: [],
      pendingQuestions: [],
      intakeComplete: false,
      eventPlan: null,
      aiPlanId: null,
      resolvedServiceIds: [],
      resolvedPackageIds: [],
      candidateVenues: [],
      candidateVendors: [],
      availabilityResults: [],
      vendorAvailabilityResults: [],
      availableVenueIds: [],
      availableVendorIds: [],
      budgetBreakdown: null,
      budgetSufficient: false,
      pricingResults: {},
      recommendations: [],
      selectedVenueId: null,
      selectedVendorIds: [],
      pendingApprovals: [],
      approvalStatus: "none",
      createdEnquiryIds: [],
      createdBookingIds: [],
      createdAllocationIds: [],
      agentHistory: [],
      completedTasks: [],
      failedTasks: [],
      retryCount: 0,
      workflowStatus: "active",
      lastError: null,
      metadata: { channel: "whatsapp", waId },
    };

    // Persist the conversationId to the identity record so next message resumes correctly
    await setIdentityConversation(waId, conversationId);
  } else {
    // Continuation — same pattern as existing /api/agent/chat
    initialState = {
      userMessage: message,
      conversationHistory: [new HumanMessage(message)],
      currentAgent: "orchestrator_agent",
    };
  }

  let result: any;
  let isInterrupted = false;

  try {
    result = await eventologyAgentApp.invoke(initialState, config);
  } catch (err: any) {
    if (err?.name === "GraphInterrupt" || err?.lc_error_code === "GRAPH_RECURSION_LIMIT") {
      isInterrupted = true;
      const stateSnapshot = await eventologyAgentApp.getState(config);
      result = stateSnapshot.values;
    } else {
      throw err;
    }
  }

  // Extract the AI response text from the conversation history
  const responseText = extractAiResponseText(result);

  // Detect pending approval
  const pendingApprovals: any[] = result?.pendingApprovals ?? [];
  const hasPendingApproval =
    isInterrupted ||
    pendingApprovals.some((a: any) => a.status === "pending") ||
    result?.approvalStatus === "pending";

  let approvalSummary: string | undefined;
  let approvalTotalCost: number | undefined;

  if (hasPendingApproval && pendingApprovals.length > 0) {
    const pending = pendingApprovals.find((a: any) => a.status === "pending");
    if (pending) {
      approvalSummary = pending.summary ?? buildApprovalSummary(result);
      approvalTotalCost = pending.totalEstimatedCost;
    }
  }

  return {
    responseText,
    conversationId,
    hasPendingApproval,
    approvalSummary,
    approvalTotalCost,
    isInterrupted,
  };
}

/**
 * Resume a suspended LangGraph workflow (approval flow) for a WhatsApp user.
 */
export async function submitApprovalForWhatsApp(
  userId: string,
  conversationId: string,
  approved: boolean
): Promise<InvokeResult> {
  const config = { configurable: { thread_id: conversationId } };

  // Verify the workflow belongs to this user
  const stateSnapshot = await eventologyAgentApp.getState(config);
  if (!stateSnapshot.values?.workflowId) {
    return {
      responseText: "I couldn't find your event plan. Please start a new conversation.",
      conversationId,
      hasPendingApproval: false,
      isInterrupted: false,
    };
  }
  if (stateSnapshot.values.userId !== userId) {
    return {
      responseText: "I'm sorry, I can't process that request.",
      conversationId,
      hasPendingApproval: false,
      isInterrupted: false,
    };
  }

  const result = await eventologyAgentApp.invoke(
    new Command({ resume: { approved, note: approved ? "Approved via WhatsApp" : "Rejected via WhatsApp" } }),
    config
  );

  const responseText = extractAiResponseText(result);
  return {
    responseText: responseText || (approved
      ? "✅ Great! Your event plan has been approved. I'm now booking your vendors and venues."
      : "No problem! Let me know what you'd like to change."),
    conversationId,
    hasPendingApproval: false,
    isInterrupted: false,
  };
}

/**
 * Extract the last AI message from the conversation history.
 */
function extractAiResponseText(state: any): string {
  const history: any[] = state?.conversationHistory ?? [];
  // Walk backwards to find the last AI message
  for (let i = history.length - 1; i >= 0; i--) {
    const msg = history[i];
    let typeStr = "";
    if (typeof msg._getType === "function") {
      typeStr = msg._getType();
    } else if (Array.isArray(msg.id) && msg.id.length > 0) {
      const last = msg.id[msg.id.length - 1];
      typeStr = String(last).toLowerCase();
    } else {
      typeStr = msg.role ?? msg.type ?? "";
    }

    const isAi = typeStr === "ai" || typeStr === "aimessage" || typeStr === "assistant";
    if (isAi) {
      const rawContent = msg.content ?? msg.kwargs?.content ?? "";
      if (typeof rawContent === "string") return rawContent;
      if (Array.isArray(rawContent)) {
        return rawContent
          .map((p: any) => (typeof p === "string" ? p : p?.text ?? p?.content ?? ""))
          .join("");
      }
    }
  }

  // Fallback: check pendingQuestions
  const questions: string[] = state?.pendingQuestions ?? [];
  if (questions.length > 0) return questions.join("\n");

  return "I've processed your request. How can I help you further?";
}

/**
 * Build a brief approval summary from state.
 */
function buildApprovalSummary(state: any): string {
  const req = state?.eventRequirements ?? {};
  const budget = state?.budgetBreakdown;
  const lines: string[] = [];
  if (req.eventType) lines.push(`📋 Event: ${req.eventType}`);
  if (req.guestCount) lines.push(`👥 Guests: ${req.guestCount}`);
  if (req.location) lines.push(`📍 Location: ${req.location}`);
  if (req.dateStr) lines.push(`📅 Date: ${req.dateStr}`);
  if (budget?.totalEstimatedCost) {
    lines.push(`💰 Estimated Budget: ₹${budget.totalEstimatedCost.toLocaleString("en-IN")}`);
  }
  return lines.join("\n");
}
