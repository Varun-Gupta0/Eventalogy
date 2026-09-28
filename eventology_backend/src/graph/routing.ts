import { StateType } from "./state";

/**
 * The orchestrator determines the next step in the graph based on the shared state.
 */
export function orchestratorRouter(state: StateType): string {
  // If there's an error, halt
  if (state.workflowStatus === "error") {
    return "__end__";
  }

  // If waiting for user input, halt execution and yield
  if (state.workflowStatus === "pending_user") {
    return "__end__";
  }

  // If the workflow is complete, end
  if (state.workflowStatus === "completed") {
    return "__end__";
  }

  // Routing logic based on stage
  if (state.currentStage === "intake" && !state.intakeComplete) {
    return "event_intake";
  }

  if (state.currentStage === "planning" || state.intakeComplete) {
    if (!state.eventPlan) {
      return "event_planning";
    }
    return "__end__";
  }

  // Fallback
  return "__end__";
}
