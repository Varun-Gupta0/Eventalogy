import { eventPlanningAgentNode } from "../agents/event_planning_agent";
import type { StateType } from "../graph/state";
import * as dotenv from "dotenv";

dotenv.config({ override: true });

async function runOptimizationTest() {
  process.env.TEST_MOCK_LLM = "true";

  const state: Partial<StateType> = {
    workflowId: "test_plan_" + Date.now(),
    conversationId: "conv_" + Date.now(),
    userId: "test_user_id",
    eventId: "test_event_id",
    currentStage: "planning",
    retryCount: 0,
    eventRequirements: {
      eventType: "Wedding",
      location: "Raipur",
      guestCount: 300,
      dateStr: "December 2026",
      budgetStr: "5 lakh",
      preferences: ["Elegant"],
    },
  };

  console.log("Starting Planning Agent Optimization Test (Mocked)");
  console.log("-----------------------------------------");

  try {
    const result = await eventPlanningAgentNode(state as any);

    console.log("\n=== Test Results ===");
    console.log("eventPlan present?", !!result.eventPlan);
    if (result.eventPlan) {
      console.log("Plan Title:", result.eventPlan.title);
      console.log("Services Requested:", result.eventPlan.requiredServices);
    }
    console.log("completedTasks:", result.completedTasks);
    console.log("workflowStatus:", result.workflowStatus);
    console.log("retryCount:", result.retryCount || 0);
  } catch (err) {
    console.error("Test failed with exception:", err);
  }
}

runOptimizationTest().catch(console.error);
