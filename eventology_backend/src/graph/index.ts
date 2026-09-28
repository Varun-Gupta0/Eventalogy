import { StateGraph, END, START, Send } from "@langchain/langgraph";
import { GraphState, type StateType, type WorkflowStage } from "./state";
import { FirestoreCheckpointer } from "../services/firestore_checkpointer";

// ─── Agent nodes ──────────────────────────────────────────────────────────────
import { orchestratorAgentNode } from "../agents/orchestrator_agent";
import { eventIntakeAgentNode } from "../agents/event_intake_agent";
import { eventPlanningAgentNode } from "../agents/event_planning_agent";
import { venueAgentNode } from "../agents/venue_agent";
import { vendorAgentNode } from "../agents/vendor_agent";
import { serviceAgentNode } from "../agents/service_agent";
import { availabilityAgentNode } from "../agents/availability_agent";
import { budgetAgentNode } from "../agents/budget_agent";
import { approvalAgentNode } from "../agents/approval_agent";
import { bookingAgentNode } from "../agents/booking_agent";
import { communicationAgentNode } from "../agents/communication_agent";

// ─── Firestore checkpointer (replaces MemorySaver) ───────────────────────────
const checkpointer = new FirestoreCheckpointer();

// ─── Orchestrator routing function ───────────────────────────────────────────
// Reads state.currentAgent (set by the orchestrator LLM) and routes accordingly.
// Returning Send[] triggers true parallel execution for specialist_search.
function orchestratorRoute(state: StateType): string | Send[] {
  const next = state.currentAgent;

  // Parallel fan-out: venue + vendor + service agents run simultaneously
  if (next === "specialist_search") {
    return [
      new Send("venue_agent", state),
      new Send("vendor_agent", state),
      new Send("service_agent", state),
    ];
  }

  if (
    next === "event_intake_agent" ||
    next === "event_planning_agent" ||
    next === "availability_agent" ||
    next === "budget_agent" ||
    next === "approval_agent" ||
    next === "booking_agent" ||
    next === "communication_agent"
  ) {
    return next;
  }

  return END;
}

// ─── Build the graph ──────────────────────────────────────────────────────────
const workflow = new StateGraph(GraphState)
  // Register all 11 nodes
  .addNode("orchestrator_agent", orchestratorAgentNode)
  .addNode("event_intake_agent", eventIntakeAgentNode)
  .addNode("event_planning_agent", eventPlanningAgentNode)
  .addNode("venue_agent", venueAgentNode)
  .addNode("vendor_agent", vendorAgentNode)
  .addNode("service_agent", serviceAgentNode)
  .addNode("availability_agent", availabilityAgentNode)
  .addNode("budget_agent", budgetAgentNode)
  .addNode("approval_agent", approvalAgentNode)
  .addNode("booking_agent", bookingAgentNode)
  .addNode("communication_agent", communicationAgentNode)

  // Entry: always start at orchestrator
  .addEdge(START, "orchestrator_agent")

  // Orchestrator is the hub — its LLM output determines what runs next
  // For specialist_search, returns Send[] for parallel execution
  .addConditionalEdges("orchestrator_agent", orchestratorRoute)

  // Every node (except communication) routes back to orchestrator after completion
  // Orchestrator then re-evaluates state and decides what's next
  .addEdge("event_intake_agent", "orchestrator_agent")
  .addEdge("event_planning_agent", "orchestrator_agent")
  .addEdge("availability_agent", "orchestrator_agent")
  .addEdge("budget_agent", "orchestrator_agent")
  .addEdge("booking_agent", "orchestrator_agent")

  // Approval routes back to orchestrator after interrupt/resume
  // Orchestrator sees approvalStatus and routes to booking or END
  .addEdge("approval_agent", "orchestrator_agent")

  // Parallel specialist agents all return to orchestrator
  // LangGraph merges their state via reducers defined in state.ts
  // Orchestrator checks completedTasks contains all three before proceeding
  .addEdge("venue_agent", "orchestrator_agent")
  .addEdge("vendor_agent", "orchestrator_agent")
  .addEdge("service_agent", "orchestrator_agent")

  // Communication is the terminal node
  .addEdge("communication_agent", END);

// ─── Compile with Firestore checkpointer ─────────────────────────────────────
export const eventologyAgentApp = workflow.compile({ checkpointer });

// Re-exports for API layer
export type { StateType, WorkflowStage };
