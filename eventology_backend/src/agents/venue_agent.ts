import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { logAgentAction } from "../services/agent_log_service";
import { executeTool } from "../utils/tool_executor";
import { searchVenuesTool, getVenueDetailsTool } from "../tools/venues";
import type { StateType, CandidateVenue } from "../graph/state";

const VenueOutputSchema = z.object({
  candidates: z.array(z.object({
    venueId: z.string(),
    name: z.string(),
    city: z.string(),
    capacity: z.number(),
    venueType: z.string(),
    basePrice: z.number().optional(),
    amenities: z.array(z.string()).optional(),
    score: z.number().min(0).max(10),
    reasoning: z.string(),
  })).describe("Shortlisted venues ranked by relevance. Maximum 5."),
  searchSummary: z.string(),
  noResultsReason: z.string().optional(),
});

export async function venueAgentNode(state: StateType): Promise<Partial<StateType>> {
  const startTime = Date.now();
  await logAgentAction(state.workflowId, "venue_agent", "start", "running");

  const tools = [searchVenuesTool, getVenueDetailsTool];
  const llm = getLLMProvider({ temperature: 0.1 }).bindTools(tools);

  const req = state.eventRequirements;
  const plan = state.eventPlan;

  const systemPrompt = `You are the Eventology Venue Agent.

Your job is to find suitable venues for an event by querying the Eventology venue database.

You must:
1. Use the search_venues tool to find venues matching the event requirements
2. If initial results are insufficient, search with broader criteria
3. Use get_venue_details to get full information on the most promising candidates
4. Reason over the results and shortlist the best 3-5 venues
5. Score each venue from 0-10 based on fit: capacity match, city match, amenities, type, price

CRITICAL: When you have finished gathering information and reasoning, you MUST call the "submit_venue_results" tool to output the final shortlist. You MUST NOT respond with plain text.

Venue selection criteria:
- Capacity must accommodate ${req.guestCount ?? "unknown"} guests (allow 20% buffer)
- City: ${req.location ?? "unspecified"}
- Venue type preferences: ${plan?.venueCharacteristics?.join(", ") ?? "none specified"}
- Budget constraint: ${req.budgetStr ?? "not specified"}
- Event type: ${req.eventType ?? "unspecified"}

Do not filter by arbitrary rules. Reason about what makes a venue suitable for this specific event.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage(`Find suitable venues for this event. Requirements: ${JSON.stringify(req)}, Plan: ${JSON.stringify(plan)}`),
  ];

  try {
    let iterations = 0;
    let finalExtraction: any = null;
    let fallbackText: string | null = null;

    const modelWithTools = getLLMProvider({ temperature: 0.1 }).bindTools([
      ...tools,
      {
        name: "submit_venue_results",
        description: "MUST be called to finalize your response. Call this when you have found suitable venues and are ready to submit the shortlist.",
        schema: VenueOutputSchema,
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
        if (tc.name === "submit_venue_results") {
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

    // Graceful fallback if the LLM refuses to use the tool
    if (!finalExtraction) {
      finalExtraction = {
        candidates: [],
        searchSummary: fallbackText || "Agent failed to output structured venue results.",
        noResultsReason: "Failed to format results correctly."
      };
    }

    const output = finalExtraction;

    const candidates: CandidateVenue[] = output.candidates.map((c: any) => ({
      venueId: c.venueId, name: c.name, city: c.city, capacity: c.capacity,
      venueType: c.venueType, basePrice: c.basePrice, amenities: c.amenities, score: c.score,
    }));

    await logAgentAction(state.workflowId, "venue_agent", "complete", "success", { candidateCount: candidates.length, durationMs: Date.now() - startTime });

    return {
      candidateVenues: candidates,

      agentHistory: [{ agent: "venue_agent", stage: "specialist_search", status: "success", startedAt: new Date(startTime).toISOString(), durationMs: Date.now() - startTime, notes: `Found ${candidates.length} candidates. ${output.searchSummary}` }],
      completedTasks: ["venue_agent"],
    };
  } catch (err: any) {
    await logAgentAction(state.workflowId, "venue_agent", "failed", "error", { error: err.message });
    return {
      failedTasks: ["venue_agent"],
      lastError: `Venue agent error: ${err.message}`,
      workflowStatus: "error",
      retryCount: (state.retryCount ?? 0) + 1,
      agentHistory: [{ agent: "venue_agent", stage: "specialist_search", status: "error", startedAt: new Date(startTime).toISOString(), notes: err.message }],
    };
  }
}
