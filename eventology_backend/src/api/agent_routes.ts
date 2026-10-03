import * as express from "express";
import { v4 as uuidv4 } from "uuid";
import { Command } from "@langchain/langgraph";
import { HumanMessage } from "@langchain/core/messages";
import { eventologyAgentApp } from "../graph";
import { verifyFirebaseToken } from "../middleware/auth";
import { db } from "../config/firebase";

export const agentRouter = express.Router();

// ─── Helpers ──────────────────────────────────────────────────────────────────

function buildThreadConfig(conversationId: string) {
  return { configurable: { thread_id: conversationId } };
}

function extractPublicState(state: any) {
  return {
    workflowId: state.workflowId,
    conversationId: state.conversationId,
    workflowStatus: state.workflowStatus,
    currentStage: state.currentStage,
    currentAgent: state.currentAgent,
    intakeComplete: state.intakeComplete,
    eventRequirements: state.eventRequirements,
    pendingQuestions: state.pendingQuestions,
    missingInformation: state.missingInformation,
    eventPlan: state.eventPlan,
    candidateVenueCount: (state.candidateVenues ?? []).length,
    candidateVendorCount: (state.candidateVendors ?? []).length,
    availableVenueCount: (state.availableVenueIds ?? []).length,
    availableVendorCount: (state.availableVendorIds ?? []).length,
    budgetBreakdown: state.budgetBreakdown,
    approvalStatus: state.approvalStatus,
    recommendations: state.recommendations,
    pendingApprovals: (state.pendingApprovals ?? []).map((a: any) => ({
      approvalId: a.approvalId,
      summary: a.summary,
      totalEstimatedCost: a.totalEstimatedCost,
      status: a.status,
      venue: a.recommendedVenueName,
      vendorCount: a.recommendedVendors?.length ?? 0,
      recommendedVendors: a.recommendedVendors ?? [],
      budgetBreakdown: a.budgetBreakdown,
    })),
    createdBookingIds: state.createdBookingIds,
    createdEnquiryIds: state.createdEnquiryIds,
    createdAllocationIds: state.createdAllocationIds,
    completedTasks: state.completedTasks,
    lastError: state.lastError,
    agentHistory: (state.agentHistory ?? []).slice(-10),
    messages: (state.conversationHistory ?? []).map((m: any) => {
      let rawContent = m.content;
      if (rawContent === undefined && m.kwargs?.content !== undefined) {
        rawContent = m.kwargs.content;
      }

      let typeStr = '';
      if (typeof m._getType === 'function') {
        typeStr = m._getType();
      } else if (Array.isArray(m.id) && m.id.length > 0) {
        const lastId = m.id[m.id.length - 1];
        if (lastId === 'HumanMessage') typeStr = 'human';
        else if (lastId === 'AIMessage') typeStr = 'ai';
        else typeStr = String(lastId).toLowerCase();
      } else {
        typeStr = m.role || m.type || '';
      }

      let role = 'assistant';
      if (typeStr === 'human' || typeStr === 'user') {
        role = 'user';
      } else if (typeStr === 'ai' || typeStr === 'assistant') {
        role = 'assistant';
      }

      let content: string;
      if (typeof rawContent === 'string') {
        content = rawContent;
      } else if (Array.isArray(rawContent)) {
        content = rawContent
          .map((part: any) => (typeof part === 'string' ? part : part?.text ?? part?.content ?? ''))
          .join('');
      } else {
        content = String(rawContent ?? '');
      }

      const msgId = typeof m.id === 'string' ? m.id : (m.kwargs?.id ?? undefined);

      return {
        role,
        content,
        id: msgId,
      };
    })
  };
}

// ─── POST /api/agent/chat ─────────────────────────────────────────────────────
// Start a new workflow or continue an existing conversation.
// Requires: Authorization: Bearer <Firebase ID Token>
// Body: { message: string, conversationId?: string, eventId?: string }

agentRouter.post("/chat", verifyFirebaseToken, async (req: express.Request, res: express.Response) => {
  const { message, conversationId, eventId } = req.body;
  const userId = (req as any).user.uid;

  if (!message || typeof message !== "string") {
    res.status(400).json({ error: "message is required and must be a string" });
    return;
  }

  const isNew = !conversationId;
  const wfId = conversationId ?? uuidv4();
  const workflowId = wfId;
  const config = buildThreadConfig(wfId);

  try {
    let initialState: Partial<any> | undefined;

    if (isNew) {
      // Fresh workflow — build complete initial state
      initialState = {
        workflowId,
        conversationId: wfId,
        userId,
        eventId: eventId ?? null,
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
        metadata: {},
      };
    } else {
      // Continuation — append user message to existing conversation
      initialState = {
        userMessage: message,
        conversationHistory: [new HumanMessage(message)],
        currentAgent: "orchestrator_agent", // re-enter orchestrator
      };
    }

    const result = await eventologyAgentApp.invoke(initialState, config);

    res.json({
      success: true,
      conversationId: wfId,
      state: extractPublicState(result),
    });
  } catch (err: any) {
    // LangGraph interrupt() surfaces as a specific type — surface correctly
    if (err?.name === "GraphInterrupt" || err?.lc_error_code === "GRAPH_RECURSION_LIMIT") {
      // Graph suspended by interrupt() — this is expected for approval
      try {
        const currentState = await eventologyAgentApp.getState(config);
        res.json({
          success: true,
          conversationId: wfId,
          interrupted: true,
          state: extractPublicState(currentState.values),
        });
      } catch {
        res.json({ success: true, conversationId: wfId, interrupted: true });
      }
      return;
    }
    console.error("[AgentRouter] /chat error:", err);
    res.status(500).json({ error: err.message ?? "Internal agent error" });
  }
});

// ─── POST /api/agent/approve ──────────────────────────────────────────────────
// Resume a suspended workflow after user approval/rejection.
// Body: { conversationId: string, approved: boolean, note?: string }

agentRouter.post("/approve", verifyFirebaseToken, async (req: express.Request, res: express.Response) => {
  const { conversationId, approved, note } = req.body;
  const userId = (req as any).user.uid;

  if (!conversationId || typeof approved !== "boolean") {
    res.status(400).json({ error: "conversationId and approved (boolean) are required" });
    return;
  }

  const config = buildThreadConfig(conversationId);

  try {
    // Verify the workflow exists and belongs to this user
    const existingState = await eventologyAgentApp.getState(config);
    if (!existingState.values || !existingState.values.workflowId) {
      res.status(404).json({ error: "Workflow not found. The conversationId may be invalid or expired." });
      return;
    }
    if (existingState.values.userId !== userId) {
      res.status(403).json({ error: "You do not have permission to approve this workflow." });
      return;
    }

    // Resume the graph with the approval decision
    // This unblocks the interrupt() in approval_agent.ts
    const result = await eventologyAgentApp.invoke(
      new Command({ resume: { approved, note: note ?? "" } }),
      config
    );

    res.json({
      success: true,
      conversationId,
      approved,
      state: extractPublicState(result),
    });
  } catch (err: any) {
    console.error("[AgentRouter] /approve error:", err);
    res.status(500).json({ error: err.message ?? "Approval processing failed" });
  }
});

// ─── GET /api/agent/status/:conversationId ────────────────────────────────────
// Get current state of a workflow without running it.

agentRouter.get("/status/:conversationId", verifyFirebaseToken, async (req: express.Request, res: express.Response) => {
  const { conversationId } = req.params;
  const userId = (req as any).user.uid;
  const config = buildThreadConfig(conversationId as string);

  try {
    const stateSnapshot = await eventologyAgentApp.getState(config);

    if (!stateSnapshot.values || Object.keys(stateSnapshot.values).length === 0) {
      res.status(404).json({ error: "Workflow not found." });
      return;
    }
    if (stateSnapshot.values.userId !== userId) {
      res.status(403).json({ error: "Permission denied." });
      return;
    }

    res.json({
      success: true,
      conversationId,
      state: extractPublicState(stateSnapshot.values),
      // Expose whether graph is waiting for user input
      pendingInterrupt: stateSnapshot.tasks?.some((t: any) => (t as any).interrupts?.length > 0) ?? false,
    });
  } catch (err: any) {
    console.error("[AgentRouter] /status error:", err);
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/agent/history/:conversationId ───────────────────────────────────
// Get the checkpoint history of a workflow.

agentRouter.get("/history/:conversationId", verifyFirebaseToken, async (req: express.Request, res: express.Response) => {
  const { conversationId } = req.params;
  const userId = (req as any).user.uid;
  const config = buildThreadConfig(conversationId as string);

  try {
    const history: any[] = [];
    for await (const snapshot of eventologyAgentApp.getStateHistory(config)) {
      history.push({
        checkpointId: snapshot.config.configurable?.checkpoint_id,
        ts: (snapshot as any).checkpoint?.ts ?? snapshot.metadata?.source,
        stage: snapshot.values?.currentStage,
        status: snapshot.values?.workflowStatus,
        agent: snapshot.values?.currentAgent,
      });
      if (history.length >= 20) break;
    }

    res.json({ success: true, conversationId, history });
  } catch (err: any) {
    console.error("[AgentRouter] /history error:", err);
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE /api/agent/:conversationId ───────────────────────────────────────
// Terminate a running workflow.

agentRouter.delete("/:conversationId", verifyFirebaseToken, async (req: express.Request, res: express.Response) => {
  const { conversationId } = req.params;
  const userId = (req as any).user.uid;
  const config = buildThreadConfig(conversationId as string);

  try {
    const existingState = await eventologyAgentApp.getState(config);
    if (existingState.values?.userId !== userId) {
      res.status(403).json({ error: "Permission denied." });
      return;
    }
    // Write a terminal state to mark as cancelled
    await eventologyAgentApp.updateState(config, {
      workflowStatus: "completed" as const,
      currentAgent: "__end__",
      currentStage: "completed" as const,
      lastError: `Cancelled by user at ${new Date().toISOString()}`,
    } as any);
    res.json({ success: true, message: "Workflow cancelled." });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
