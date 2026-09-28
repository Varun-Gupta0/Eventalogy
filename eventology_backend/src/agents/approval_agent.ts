import { interrupt } from "@langchain/langgraph";
import { logAgentAction } from "../services/agent_log_service";
import { createAgentTask, updateAgentTaskStatus } from "../services/agent_task_service";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import type { StateType, ApprovalRequest } from "../graph/state";

/**
 * Approval Agent — Human-in-the-Loop interrupt node.
 *
 * This is NOT a simulated boolean check. This uses LangGraph's interrupt()
 * function which genuinely suspends graph execution, persists state via the
 * checkpointer, and waits for the user to resume via POST /api/agent/approve.
 *
 * Flow:
 *   1. Build approval request from current recommendations + budget
 *   2. Persist to Firestore agent_tasks so admin can see it
 *   3. Call interrupt() — graph SUSPENDS here. Control returns to API caller.
 *   4. Code after interrupt() only runs when the graph is resumed via Command({ resume: ... })
 *   5. Apply the user's decision and return updated state
 */
export async function approvalAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  
  try {
    await logAgentAction(state.workflowId, "approval_agent", "preparing_approval", "running");

    // ── Build the approval request ──────────────────────────────────────────────
    const selectedVenue = (state.candidateVenues ?? []).find(v => v.venueId === state.selectedVenueId);
    const selectedVendors = (state.candidateVendors ?? []).filter(v =>
      state.selectedVendorIds?.includes(v.vendorId)
    );

    const approvalRequest: ApprovalRequest = {
      approvalId: `approval_${state.workflowId}_${Date.now()}`,
      workflowId: state.workflowId,
      summary: buildApprovalSummary(state),
      recommendedVenueId: state.selectedVenueId ?? undefined,
      recommendedVenueName: selectedVenue?.name,
      recommendedVendors: selectedVendors.map(v => ({
        vendorId: v.vendorId,
        name: v.name,
        serviceCategory: v.serviceCategory,
        estimatedCost: state.pricingResults?.[v.vendorId] ?? 0,
      })),
      totalEstimatedCost: state.budgetBreakdown?.totalEstimatedCost ?? 0,
      budgetBreakdown: state.budgetBreakdown ?? null,
      status: "pending",
      requestedAt: new Date().toISOString(),
    };

    // ── Persist approval request to Firestore ──────────────────────────────────
    // This makes the pending approval visible in the Admin Dashboard
    const taskId = await createAgentTask(
      state.workflowId, "approval_agent", "pending_approval",
      { approvalRequest }, true // requiresApproval = true
    );

    // Also write a separate approval_requests record for easy UI querying
    const approvalRef = db.collection("agent_tasks").doc(taskId);
    await approvalRef.update({
      approvalRequest,
      requiresApproval: true,
      workflowId: state.workflowId,
      userId: state.userId,
    });

    await logAgentAction(state.workflowId, "approval_agent", "awaiting_user_decision", "running", {
      approvalId: approvalRequest.approvalId,
      totalCost: approvalRequest.totalEstimatedCost,
    });

    // ── INTERRUPT — graph suspends here ────────────────────────────────────────
    // LangGraph persists the full state via the Firestore checkpointer.
    // The API returns workflowStatus: "pending_user" to the client.
    // Execution resumes ONLY when POST /api/agent/approve is called with:
    //   { approved: true/false, note: string }
    const userDecision = interrupt({
      type: "approval_required",
      approvalId: approvalRequest.approvalId,
      summary: approvalRequest.summary,
      totalEstimatedCost: approvalRequest.totalEstimatedCost,
      venue: approvalRequest.recommendedVenueName,
      vendorCount: approvalRequest.recommendedVendors.length,
      budgetBreakdown: approvalRequest.budgetBreakdown,
    });

    // ── Code below runs AFTER resume ───────────────────────────────────────────
    const approved: boolean = userDecision?.approved === true;
    const userNote: string = userDecision?.note ?? "";

    await updateAgentTaskStatus(taskId, approved ? "approved" : "rejected", { approved, note: userNote });
    await logAgentAction(state.workflowId, "approval_agent", "decision_received", approved ? "success" : "rejected", {
      approved,
      note: userNote,
      durationMs: Date.now() - startTime,
    });

    // Also persist decision into Firestore for audit trail
    await db.collection("agent_tasks").doc(taskId).update({
      "approvalRequest.status": approved ? "approved" : "rejected",
      "approvalRequest.userDecision": userNote,
      "approvalRequest.decidedAt": new Date().toISOString(),
      decidedAt: FieldValue.serverTimestamp(),
    });

    const updatedApproval: ApprovalRequest = {
      ...approvalRequest,
      status: approved ? "approved" : "rejected",
      userDecision: userNote,
      decidedAt: new Date().toISOString(),
    };

    return {
      approvalStatus: approved ? "approved" : "rejected",
      pendingApprovals: [updatedApproval],
      currentAgent: "orchestrator_agent",
      currentStage: approved ? "booking" : "completed",
      workflowStatus: approved ? "active" : "completed",
      agentHistory: [{
        agent: "approval_agent",
        stage: "approval_pending",
        status: approved ? "success" : "skipped",
        startedAt: new Date(startTime).toISOString(),
        durationMs: Date.now() - startTime,
        notes: `User decision: ${approved ? "APPROVED" : "REJECTED"}. ${userNote}`,
      }],
      completedTasks: ["approval_agent"],
    };
  } catch (err: any) {
    if (err?.name === "GraphInterrupt" || err?.lc_error_code === "GRAPH_RECURSION_LIMIT") {
      throw err; // Re-throw so LangGraph can suspend correctly
    }
    await logAgentAction(state.workflowId, "approval_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["approval_agent"],
      lastError: `Approval error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "approval_agent", stage: "approval_pending", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}

function buildApprovalSummary(state: StateType): string {
  const req = state.eventRequirements;
  const bd = state.budgetBreakdown;
  return [
    `Event: ${req.eventType ?? "Event"} for ${req.guestCount ?? "?"} guests in ${req.location ?? "?"}`,
    `Date: ${req.dateStr ?? "TBD"}`,
    `Venue: ${(state.candidateVenues ?? []).find(v => v.venueId === state.selectedVenueId)?.name ?? "No venue selected"}`,
    `Vendors: ${state.selectedVendorIds?.length ?? 0} selected`,
    `Total estimated cost: INR ${bd?.totalEstimatedCost?.toLocaleString("en-IN") ?? "unknown"}`,
    bd?.withinBudget ? "✓ Within budget" : `⚠ Over budget by INR ${bd?.overageAmount?.toLocaleString("en-IN") ?? "?"}`,
  ].join(" | ");
}
