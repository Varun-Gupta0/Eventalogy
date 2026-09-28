import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { getServicesByCategoryTool, getAllCategoriesTool, getPackagesTool } from "../tools/services";
import type { StateType, ResolvedService } from "../graph/state";

const ServiceOutputSchema = z.object({
  resolvedServices: z.array(z.object({
    serviceId: z.string(),
    name: z.string(),
    categoryId: z.string(),
    categoryName: z.string(),
    priority: z.enum(["required", "recommended", "optional"]),
    reasoning: z.string(),
  })),
  suggestedPackageIds: z.array(z.string()),
  resolutionSummary: z.string(),
});

export async function serviceAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "service_agent", "start", "running");

  const tools = [getServicesByCategoryTool, getAllCategoriesTool, getPackagesTool];
  const llm = getLLMProvider({ temperature: 0.1 }).bindTools(tools);

  const req = state.eventRequirements;
  const plan = state.eventPlan;

  const systemPrompt = `You are the Eventology Service Agent.

Your job is to resolve the services listed in the event plan into actual Firestore service IDs.

Event plan services: ${plan?.requiredServices?.join(", ") ?? "none specified"}

Your responsibilities:
1. Use get_all_categories to see what service categories exist in the system
2. For each relevant category, use get_services_by_category to get actual service records with IDs
3. Match each service in the plan to real Firestore service documents with IDs
4. Identify which services are required vs optional for this specific event
5. Check if any packages from get_packages could cover multiple services efficiently
6. Consider Indian event context for ${req.eventType ?? "general"} events

Event context: Type=${req.eventType}, Location=${req.location}, Guests=${req.guestCount}

Be precise with serviceIds as these will be used directly for booking.

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_service_results" tool to output the final resolved services. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Resolve these services to Firestore IDs: ${plan?.requiredServices?.join(", ")}. Event: ${JSON.stringify(req)}`),
  ];

  try {
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.1 }).bindTools([
      ...tools,
      {
        name: "submit_service_results",
        description: "MUST be called to finalize your response. Call this when you have resolved the required services to Firestore IDs.",
        schema: ServiceOutputSchema,
      }
    ]);

    while (iterations < 6) {
      const response = await modelWithTools.invoke(messages) as AIMessage;
      messages.push(response);
      
      if (response.content && typeof response.content === 'string') {
        fallbackText = response.content;
      }
      
      if (!response.tool_calls?.length) break;
      
      let extractionFound = false;
      
      for (const tc of response.tool_calls) {
        if (tc.name === "submit_service_results") {
          finalExtraction = tc.args;
          extractionFound = true;
          break;
        } else {
          const toolToRun = tools.find(t => t.name === tc.name);
          if (toolToRun) {
            const result = await executeTool([toolToRun] as any, tc);
            messages.push(new ToolMessage({ content: result, tool_call_id: tc.id! }));
          }
        }
      }
      
      if (extractionFound) break;
      iterations++;
    }

    if (!finalExtraction) {
      finalExtraction = {
        resolvedServices: [],
        suggestedPackageIds: [],
        resolutionSummary: fallbackText || "Agent failed to output structured service results.",
      };
    }

    const output = finalExtraction;

    const resolved: ResolvedService[] = output.resolvedServices.map((s: any) => ({
      serviceId: s.serviceId, name: s.name, categoryId: s.categoryId, categoryName: s.categoryName,
    }));

    await logAgentAction(state.workflowId, "service_agent", "complete", "success", { resolvedCount: resolved.length, durationMs: Date.now() - startTime });

    return {
      resolvedServiceIds: resolved,
      resolvedPackageIds: output.suggestedPackageIds,

      agentHistory: [{ agent: "service_agent", stage: "specialist_search", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Resolved ${resolved.length} services. ${output.resolutionSummary}` }],
      completedTasks: ["service_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "service_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["service_agent"],
      lastError: `Service agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "service_agent", stage: "specialist_search", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
