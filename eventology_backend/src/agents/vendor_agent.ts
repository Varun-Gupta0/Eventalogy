import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { searchVendorsByServiceTool, getVendorDetailsTool } from "../tools/vendors";
import type { StateType, CandidateVendor } from "../graph/state";

const VendorOutputSchema = z.object({
  candidates: z.array(z.object({
    vendorId: z.string(),
    name: z.string(),
    serviceCategory: z.string(),
    city: z.string(),
    rating: z.number().optional(),
    priceRange: z.string().optional(),
    score: z.number().min(0).max(10),
    reasoning: z.string(),
  })).describe("Shortlisted vendors. Maximum 3 per service category."),
  coveredServices: z.array(z.string()),
  uncoveredServices: z.array(z.string()),
  searchSummary: z.string(),
});

export async function vendorAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "vendor_agent", "start", "running");

  const tools = [searchVendorsByServiceTool, getVendorDetailsTool];
  const llm = getLLMProvider({ temperature: 0.1 }).bindTools(tools);

  const req = state.eventRequirements;
  const requiredServices = state.eventPlan?.requiredServices ?? [];

  const systemPrompt = `You are the Eventology Vendor Agent.

Your job is to find suitable vendors for each service required by the event plan.

Required services: ${requiredServices.join(", ")}
Event location: ${req.location ?? "unspecified"}
Event type: ${req.eventType ?? "unspecified"}
Guest count: ${req.guestCount ?? "unknown"}
Budget: ${req.budgetStr ?? "not specified"}

Instructions:
1. For EACH required service, use search_vendors_by_service to find vendors
2. If a service search returns no results, try a related search term
3. For top 2-3 candidates per service, use get_vendor_details for full information
4. Score each vendor 0-10 based on: rating, price fit, city match, and service relevance
5. You may find multiple vendors per service category for comparison in the budget phase

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_vendor_results" tool to output the final shortlist. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Find vendors for these services: ${requiredServices.join(", ")}. Event: ${JSON.stringify(req)}`),
  ];

  try {
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.1 }).bindTools([
      ...tools,
      {
        name: "submit_vendor_results",
        description: "MUST be called to finalize your response. Call this when you have found suitable vendors and are ready to submit the shortlist.",
        schema: VendorOutputSchema,
      }
    ]);

    while (iterations < 10) {
      const response = await modelWithTools.invoke(messages) as AIMessage;
      messages.push(response);
      
      if (response.content && typeof response.content === 'string') {
        fallbackText = response.content;
      }
      
      if (!response.tool_calls?.length) break;
      
      let extractionFound = false;
      
      for (const tc of response.tool_calls) {
        if (tc.name === "submit_vendor_results") {
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
        candidates: [],
        coveredServices: [],
        uncoveredServices: requiredServices,
        searchSummary: fallbackText || "Agent failed to output structured vendor results.",
      };
    }

    const output = finalExtraction;

    const candidates: CandidateVendor[] = output.candidates.map((c: any) => ({
      vendorId: c.vendorId, name: c.name, serviceCategory: c.serviceCategory,
      city: c.city, rating: c.rating, priceRange: c.priceRange, score: c.score,
    }));

    await logAgentAction(state.workflowId, "vendor_agent", "complete", "success", { candidateCount: candidates.length, durationMs: Date.now() - startTime });

    return {
      candidateVendors: candidates,

      agentHistory: [{ agent: "vendor_agent", stage: "specialist_search", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Found ${candidates.length} vendors across ${output.coveredServices.length} services. Uncovered: ${output.uncoveredServices.join(", ") || "none"}` }],
      completedTasks: ["vendor_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "vendor_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["vendor_agent"],
      lastError: `Vendor agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "vendor_agent", stage: "specialist_search", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
