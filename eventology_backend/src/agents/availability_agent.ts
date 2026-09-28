import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { checkVenueAvailabilityTool, checkVendorAvailabilityTool } from "../tools/availability";
import type { StateType, AvailabilityResult, VendorAvailabilityResult } from "../graph/state";

const AvailabilityOutputSchema = z.object({
  venueResults: z.array(z.object({
    venueId: z.string(),
    available: z.boolean(),
    conflictReason: z.string().optional(),
  })),
  vendorResults: z.array(z.object({
    vendorId: z.string(),
    serviceCategory: z.string(),
    available: z.boolean(),
    conflictReason: z.string().optional(),
  })),
  availableVenueIds: z.array(z.string()),
  availableVendorIds: z.array(z.string()),
  summary: z.string(),
  warningsOrIssues: z.array(z.string()),
});

export async function availabilityAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "availability_agent", "start", "running");

  const tools = [checkVenueAvailabilityTool, checkVendorAvailabilityTool];
  const llm = getLLMProvider({ temperature: 0.0 }).bindTools(tools);

  const dateStr = state.eventRequirements.dateStr ?? "unspecified";
  const venues = state.candidateVenues ?? [];
  const vendors = state.candidateVendors ?? [];

  const venueList = venues.map(v => `${v.venueId}: ${v.name}`).join(", ");
  const vendorList = vendors.map(v => `${v.vendorId}: ${v.name} (${v.serviceCategory})`).join(", ");

  const systemPrompt = `You are the Eventology Availability Agent.

Your job is to check whether shortlisted venues and vendors are available on the event date.

Event date: ${dateStr}

Candidate venues to check: ${venueList || "none"}
Candidate vendors to check: ${vendorList || "none"}

Instructions:
1. Check ALL candidate venues using check_venue_availability
2. Check ALL candidate vendors using check_vendor_availability
3. Report which are available and which have conflicts
4. If a candidate is unavailable, note the reason clearly

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_availability_results" tool to output the final results. You MUST NOT respond with plain text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Check availability for all ${venues.length} venues and ${vendors.length} vendors on ${dateStr}.`),
  ];

  try {
    const maxIter = Math.max(10, venues.length + vendors.length + 2);
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.0 }).bindTools([
      ...tools,
      {
        name: "submit_availability_results",
        description: "MUST be called to finalize your response. Call this when you have checked all candidate venues and vendors.",
        schema: AvailabilityOutputSchema,
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
        if (tc.name === "submit_availability_results") {
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
        venueResults: [],
        vendorResults: [],
        availableVenueIds: [],
        availableVendorIds: [],
        summary: fallbackText || "Agent failed to output structured availability results.",
        warningsOrIssues: ["Failed to format results correctly"]
      };
    }

    const output = finalExtraction;

    await logAgentAction(state.workflowId, "availability_agent", "complete", "success", { availableVenues: output.availableVenueIds.length, availableVendors: output.availableVendorIds.length, durationMs: Date.now() - startTime });

    return {
      availabilityResults: output.venueResults as AvailabilityResult[],
      vendorAvailabilityResults: output.vendorResults.map((r: any) => ({ ...r, serviceId: "" })) as VendorAvailabilityResult[],
      availableVenueIds: output.availableVenueIds,
      availableVendorIds: output.availableVendorIds,
      currentAgent: "orchestrator_agent",
      currentStage: "availability",
      agentHistory: [{ agent: "availability_agent", stage: "availability", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `${output.availableVenueIds.length} venues, ${output.availableVendorIds.length} vendors available. ${output.summary}` }],
      completedTasks: ["availability_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "availability_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["availability_agent"],
      lastError: `Availability agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "availability_agent", stage: "availability", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
