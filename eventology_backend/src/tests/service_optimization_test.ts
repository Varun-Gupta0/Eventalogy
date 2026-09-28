import { serviceAgentNode } from "../agents/service_agent";
import type { StateType } from "../graph/state";
import * as dotenv from "dotenv";

dotenv.config({ override: true });

async function runOptimizationTest() {
  process.env.TEST_MOCK_LLM = "service";

  const state: Partial<StateType> = {
    workflowId: "test_service_" + Date.now(),
    conversationId: "conv_" + Date.now(),
    userId: "test_user_id",
    eventId: "test_event_id",
    currentStage: "specialist_search",
    retryCount: 0,
    eventRequirements: {
      eventType: "Wedding",
      location: "Raipur",
      guestCount: 300,
      dateStr: "December 2026",
      budgetStr: "5 lakh",
    },
    eventPlan: {
      title: "Wedding Plan",
      summary: "...",
      requiredServices: ["Catering"],
      venueCharacteristics: [],
      estimatedInitialBudget: 500000,
      dependencies: []
    }
  };

  console.log("Starting Service Agent Optimization Test (Mocked)");
  console.log("-----------------------------------------");

  try {
    const result = await serviceAgentNode(state as any);

    console.log("\n=== Test Results ===");
    console.log("resolvedServiceIds present?", !!result.resolvedServiceIds);
    if (result.resolvedServiceIds) {
      console.log("Services resolved:", result.resolvedServiceIds.length);
      console.log("First service:", result.resolvedServiceIds[0]?.name);
    }
    console.log("completedTasks:", result.completedTasks);
    console.log("workflowStatus:", result.workflowStatus);
    console.log("retryCount:", result.retryCount || 0);
  } catch (err) {
    console.error("Test failed with exception:", err);
  }
}

runOptimizationTest().catch(console.error);
