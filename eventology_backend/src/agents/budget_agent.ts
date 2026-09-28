import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { getVenuePricingTool } from "../tools/venues";
import { getVendorPricingTool } from "../tools/vendors";
import { getPackagePricingTool } from "../tools/services";
import type { StateType, BudgetBreakdown, Recommendation } from "../graph/state";

const BudgetOutputSchema = z.object({
  selectedVenueId: z.string().nullable(),
  selectedVendorIds: z.array(z.string()),
  recommendations: z.array(z.object({
    type: z.enum(["venue", "vendor", "package"]),
    entityId: z.string(),
    name: z.string(),
    reason: z.string(),
    estimatedCost: z.number(),
  })),
  budgetBreakdown: z.object({
    totalEstimatedCost: z.number(),
    lineItems: z.array(z.object({
      category: z.string(),
      vendorId: z.string().optional(),
      venueId: z.string().optional(),
      description: z.string(),
      estimatedCost: z.number(),
    })),
    withinBudget: z.boolean(),
    overageAmount: z.number().optional(),
    notes: z.string(),
  }),
  budgetSufficient: z.boolean(),
  alternativeOption: z.string().optional(),
});

export async function budgetAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "budget_agent", "start", "running");

  const tools = [getVenuePricingTool, getVendorPricingTool, getPackagePricingTool];
  const llm = getLLMProvider({ temperature: 0.1 }).bindTools(tools);

  const availableVenues = (state.candidateVenues ?? []).filter(v => (state.availableVenueIds ?? []).includes(v.venueId));
  const availableVendors = (state.candidateVendors ?? []).filter(v => (state.availableVendorIds ?? []).includes(v.vendorId));
  const packages = state.resolvedPackageIds ?? [];

  const venueList = availableVenues.map(v => `${v.venueId}: ${v.name} (score:${v.score})`).join(", ");
  const vendorList = availableVendors.map(v => `${v.vendorId}: ${v.name} (${v.serviceCategory}, score:${v.score})`).join(", ");

  const systemPrompt = `You are the Eventology Budget Agent.

Your job is to retrieve pricing and recommend the optimal combination of venue + vendors within budget.

Event budget: ${state.eventRequirements.budgetStr ?? "not specified"}
Guest count: ${state.eventRequirements.guestCount ?? "unknown"}
Event type: ${state.eventRequirements.eventType ?? "unspecified"}

Available venues (${availableVenues.length}): ${venueList || "none"}
Available vendors (${availableVendors.length}): ${vendorList || "none"}
Packages: ${packages.join(", ") || "none"}

Instructions:
1. Use get_venue_pricing for each available venue
2. Use get_vendor_pricing for each available vendor
3. If packages exist, use get_package_pricing to evaluate them
4. Select the best combination: within budget, covers all required services, maximises quality
5. Build an itemised budget breakdown
6. If over budget, state by how much and suggest one specific reduction

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_budget_results" tool to output the final results. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Compute pricing and recommend the optimal vendor/venue combination.`),
  ];

  try {
    const maxIter = Math.max(8, availableVenues.length + availableVendors.length + 2);
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.1 }).bindTools([
      ...tools,
      {
        name: "submit_budget_results",
        description: "MUST be called to finalize your response. Call this when you have computed the budget breakdown and recommendations.",
        schema: BudgetOutputSchema,
      }
    ]);

    while (iterations < maxIter) {
      const response = await modelWithTools.invoke(messages) as AIMessage;
      messages.push(response);
      
      if (response.content && typeof response.content === 'string') {
        fallbackText = response.content;
      }
      
      if (!response.tool_calls?.length) break;
      
      let extractionFound = false;
      
      for (const tc of response.tool_calls) {
        if (tc.name === "submit_budget_results") {
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
        selectedVenueId: null,
        selectedVendorIds: [],
        recommendations: [],
        budgetBreakdown: {
          totalEstimatedCost: 0,
          lineItems: [],
          withinBudget: false,
          notes: fallbackText || "Agent failed to output structured budget results."
        },
        budgetSufficient: false,
        alternativeOption: "Failed to format results correctly"
      };
    }

    const output = finalExtraction;

    await logAgentAction(state.workflowId, "budget_agent", "complete", "success", { total: output.budgetBreakdown.totalEstimatedCost, withinBudget: output.budgetSufficient, durationMs: Date.now() - startTime });

    return {
      selectedVenueId: output.selectedVenueId,
      selectedVendorIds: output.selectedVendorIds,
      recommendations: output.recommendations as Recommendation[],
      budgetBreakdown: output.budgetBreakdown as BudgetBreakdown,
      budgetSufficient: output.budgetSufficient,
      pricingResults: Object.fromEntries(output.recommendations.map(r => [r.entityId, r.estimatedCost])),
      currentAgent: "orchestrator_agent",
      currentStage: "budget",
      agentHistory: [{ agent: "budget_agent", stage: "budget", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Total: INR ${output.budgetBreakdown.totalEstimatedCost} | withinBudget: ${output.budgetSufficient}` }],
      completedTasks: ["budget_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "budget_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["budget_agent"],
      lastError: `Budget agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "budget_agent", stage: "budget", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
