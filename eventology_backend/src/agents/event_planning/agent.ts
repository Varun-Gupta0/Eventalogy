import { z } from "zod";
import { StateType } from "../../graph/state";
import { getLLMProvider } from "../../llm/provider";
import { SystemMessage, HumanMessage } from "@langchain/core/messages";
import { saveAIPlan } from "../../services/ai_plan_service";
import { logAgentAction } from "../../services/agent_log_service";
import { createAgentTask, updateAgentTaskStatus } from "../../services/agent_task_service";

const PlanningOutputSchema = z.object({
  title: z.string().describe("A catchy title for the event"),
  summary: z.string().describe("A professional summary of the event plan"),
  requiredServices: z.array(z.string()).describe("List of service categories required (e.g., Catering, Photography, Decoration, Venue)"),
  venueCharacteristics: z.array(z.string()).describe("Important characteristics required of the venue (e.g., indoor, large capacity, outdoor lawn)"),
  estimatedInitialBudget: z.number().describe("An initial rough budget estimate in INR based on requirements"),
  dependencies: z.array(z.string()).describe("Critical dependencies (e.g., 'Venue must be booked before Decoration')")
});

export async function eventPlanningNode(state: StateType): Promise<Partial<StateType>> {
  await logAgentAction(state.workflowId, "event_planning", "start_planning", "running");
  const taskId = await createAgentTask(state.workflowId, "event_planning", "running", { requirements: state.eventRequirements }, false);

  const llm = getLLMProvider({ temperature: 0.2 });
  const structuredLlm = llm.withStructuredOutput(PlanningOutputSchema, { name: "event_planning" });

  const systemPrompt = `You are the Eventology Event Planning Agent.
You receive structured event requirements and generate a comprehensive event plan.
Consider the location, guest count, event type, and budget constraints.
Determine exactly what services will be needed for this specific event.
Do not use a generic list; adapt to the specific event scale and type provided.
Your output must be a structured plan.`;

  const messages = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Create a plan for these requirements:\n${JSON.stringify(state.eventRequirements, null, 2)}`)
  ];

  try {
    const plan = await structuredLlm.invoke(messages);
    
    // Persist to Firestore AI Plans
    const planId = await saveAIPlan({
      userId: state.userId,
      eventId: state.eventId,
      eventRequirements: state.eventRequirements,
      recommendations: plan.requiredServices,
      estimatedBudget: plan.estimatedInitialBudget.toString(),
      status: "generated"
    });

    await updateAgentTaskStatus(taskId, "completed", plan);
    await logAgentAction(state.workflowId, "event_planning", "complete_planning", "success", { planId, title: plan.title });

    return {
      eventPlan: plan,
      workflowStatus: "completed" // In this MVP, planning is the final step
    };
  } catch (error: any) {
    await updateAgentTaskStatus(taskId, "error", null, error.message);
    await logAgentAction(state.workflowId, "event_planning", "planning_failed", "error", { error: error.message });

    return {
      lastError: `Planning Error: ${error.message}`,
      workflowStatus: "error"
    };
  }
}
