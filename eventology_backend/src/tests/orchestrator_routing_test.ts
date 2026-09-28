import { orchestratorAgentNode } from "../agents/orchestrator_agent";
import { StateType } from "../graph/state";

async function runTests() {
  const baseState: Partial<StateType> = {
    workflowId: "test", userId: "test", conversationId: "test",
    currentStage: "intake", currentAgent: "orchestrator_agent",
    conversationHistory: [], eventRequirements: {},
    workflowStatus: "active",
  };

  const testCases = [
    { name: "New Workflow", state: { ...baseState, intakeComplete: false }, expected: "event_intake_agent" },
    { name: "Intake Complete", state: { ...baseState, intakeComplete: true }, expected: "event_planning_agent" },
    { name: "Pending User", state: { ...baseState, workflowStatus: "pending_user" }, expected: "__end__" },
    { name: "Retry Failed", state: { ...baseState, failedTasks: ["venue_agent"], retryCount: 1 }, expected: "venue_agent" },
    { name: "Max Retries", state: { ...baseState, failedTasks: ["venue_agent"], retryCount: 3 }, expected: "__end__" },
    { name: "Specialist Search", state: { ...baseState, intakeComplete: true, eventPlan: { title: "Test", summary: "", requiredServices: [], venueCharacteristics: [], estimatedInitialBudget: 0, dependencies: [] }, completedTasks: ["event_planning_agent"] }, expected: "specialist_search" },
  ];

  for (const tc of testCases) {
    const res = await orchestratorAgentNode(tc.state as any);
    console.log(`${tc.name}: Expected ${tc.expected}, Got ${res.currentAgent} -> ${res.currentAgent === tc.expected ? "PASS" : "FAIL"}`);
  }
}

runTests();