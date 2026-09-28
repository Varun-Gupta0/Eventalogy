import { venueAgentNode } from "../agents/venue_agent";
import type { StateType } from "../graph/state";
import * as dotenv from "dotenv";

dotenv.config({ override: true });

async function runOptimizationTest() {
  process.env.TEST_MOCK_LLM = "true";

  const state: Partial<StateType> = {
    workflowId: "test_venue_" + Date.now(),
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
      requiredServices: [],
      venueCharacteristics: ["Banquet"],
      estimatedInitialBudget: 500000,
      dependencies: []
    }
  };

  console.log("Starting Venue Agent Optimization Test (Mocked)");
  console.log("-----------------------------------------");

  try {
    const result = await venueAgentNode(state as any);

    console.log("\n=== Test Results ===");
    console.log("candidateVenues present?", !!result.candidateVenues);
    if (result.candidateVenues) {
      console.log("Candidates found:", result.candidateVenues.length);
      console.log("First candidate:", result.candidateVenues[0]?.name);
    }
    console.log("completedTasks:", result.completedTasks);
    console.log("workflowStatus:", result.workflowStatus);
    console.log("retryCount:", result.retryCount || 0);
  } catch (err) {
    console.error("Test failed with exception:", err);
  }
}

runOptimizationTest().catch(console.error);
