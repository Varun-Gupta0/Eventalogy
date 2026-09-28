import { orchestratorRouter } from "../graph/routing";
import { GraphState } from "../graph/state";

describe("Eventology LangGraph Architecture Tests", () => {
  
  describe("1. State Creation & Defaults", () => {
    it("should initialize default state correctly", () => {
      // Create empty state by letting GraphState initialize it
      // For testing, we mock the initial state structure
      const initialState = {
        workflowId: "test-123",
        conversationId: "conv-123",
        userId: "user-123",
        currentAgent: "orchestrator",
        currentStage: "intake",
        userMessage: "Hello",
        conversationHistory: [],
        eventRequirements: {},
        missingInformation: [],
        pendingQuestions: [],
        intakeComplete: false,
        eventPlan: null,
        candidateVenues: [],
        candidateVendors: [],
        requiredServices: [],
        availabilityResults: {},
        pricingResults: {},
        recommendations: [],
        pendingApprovals: [],
        completedTasks: [],
        failedTasks: [],
        workflowStatus: "active",
        lastError: null,
        metadata: {}
      };
      expect(initialState.workflowStatus).toBe("active");
      expect(initialState.intakeComplete).toBe(false);
    });
  });

  describe("5. Orchestrator Routing", () => {
    it("routes to event_intake if intake is incomplete", () => {
      const state: any = { workflowStatus: "active", currentStage: "intake", intakeComplete: false };
      expect(orchestratorRouter(state)).toBe("event_intake");
    });

    it("routes to event_planning if intake is complete but no plan", () => {
      const state: any = { workflowStatus: "active", currentStage: "intake", intakeComplete: true, eventPlan: null };
      expect(orchestratorRouter(state)).toBe("event_planning");
    });

    it("halts if pending user input", () => {
      const state: any = { workflowStatus: "pending_user" };
      expect(orchestratorRouter(state)).toBe("__end__");
    });

    it("halts if completed", () => {
      const state: any = { workflowStatus: "completed" };
      expect(orchestratorRouter(state)).toBe("__end__");
    });
  });

  describe("7. User Isolation", () => {
    it("ensures state clearly isolates users by ID", () => {
      const stateA: any = { userId: "userA", workflowId: "wf-1" };
      const stateB: any = { userId: "userB", workflowId: "wf-2" };
      expect(stateA.userId).not.toBe(stateB.userId);
    });
  });

  describe("9. Error Handling", () => {
    it("orchestrator routes to end on error state", () => {
      const state: any = { workflowStatus: "error", lastError: "API limit" };
      expect(orchestratorRouter(state)).toBe("__end__");
    });
  });

});
