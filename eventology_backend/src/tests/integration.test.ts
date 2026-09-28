import { eventologyAgentApp } from "../graph";
import { HumanMessage } from "@langchain/core/messages";

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        set: jest.fn().mockResolvedValue({}),
        update: jest.fn().mockResolvedValue({}),
        get: jest.fn().mockResolvedValue({ exists: false }),
        collection: jest.fn(() => ({
          doc: jest.fn(() => ({
            set: jest.fn().mockResolvedValue({}),
            get: jest.fn().mockResolvedValue({ exists: false })
          })),
          orderBy: jest.fn().mockReturnThis(),
          limit: jest.fn().mockReturnThis(),
          get: jest.fn().mockResolvedValue({ docs: [], empty: true })
        })),
        id: "mock-id"
      })),
      where: jest.fn().mockReturnThis(),
      get: jest.fn().mockResolvedValue({ docs: [], empty: true })
    })),
    batch: jest.fn(() => ({
      set: jest.fn(),
      commit: jest.fn().mockResolvedValue({})
    }))
  })),
  FieldValue: {
    serverTimestamp: jest.fn(() => "mock-timestamp")
  }
}));

jest.mock("firebase-admin/app", () => ({
  getApps: jest.fn(() => [{}]),
  initializeApp: jest.fn()
}));


describe("LangGraph Agent Integration", () => {
  it("runs the intake extraction properly if API key is present", async () => {
    // Only run if API key is provided
    if (!process.env.OPENROUTER_API_KEY && !process.env.GEMINI_API_KEY) {
      console.warn("Skipping integration test: No API_KEY provided");
      return;
    }

    const inputState = {
      userId: "test-user-1",
      conversationId: "test-conv-1",
      workflowId: "test-workflow-1",
      eventId: null,
      currentAgent: "event_intake_agent" as const,
      currentStage: "intake" as const,
      userMessage: "I want to host a birthday party for 50 people in Mumbai next week.",
      conversationHistory: [new HumanMessage("I want to host a birthday party for 50 people in Mumbai next week.")],
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
      pricingResults: {},
      budgetBreakdown: null,
      budgetSufficient: false,
      selectedVenueId: null,
      selectedVendorIds: [],
      recommendations: [],
      pendingApprovals: [],
      approvalStatus: "none" as const,
      createdEnquiryIds: [],
      createdBookingIds: [],
      createdAllocationIds: [],
      agentHistory: [],
      completedTasks: [],
      failedTasks: [],
      retryCount: 0,
      workflowStatus: "active" as const,
      lastError: null,
      metadata: {},
    };


    const result = await eventologyAgentApp.invoke(inputState, { configurable: { thread_id: "test-conv-1" } });
    
    // We expect the LLM to have extracted some data and transitioned either to asking budget/date, or moving on
    expect(result.workflowStatus).not.toBe("error");
    expect(result.eventRequirements).toBeDefined();
    
    // Birthday party extraction
    expect(result.eventRequirements.eventType?.toLowerCase()).toContain("birthday");
    expect(result.eventRequirements.guestCount).toBe(50);
    expect(result.eventRequirements.location?.toLowerCase()).toContain("mumbai");
  }, 60000);
});
