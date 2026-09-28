import { z } from "zod";
import { SystemMessage, HumanMessage, AIMessage, ToolMessage } from "@langchain/core/messages";
import { getLLMProvider } from "../llm/provider";
import { tool } from "@langchain/core/tools";

const IntakeOutputSchema = z.object({
  extractedRequirements: z.object({
    eventType: z.string().optional(),
    guestCount: z.number().optional(),
    location: z.string().optional(),
    dateStr: z.string().optional(),
    budgetStr: z.string().optional(),
    preferences: z.array(z.string()).optional(),
    constraints: z.array(z.string()).optional(),
  }),
  missingInformation: z.array(z.string()),
  nextQuestion: z.string().optional(),
  isComplete: z.boolean(),
  confidence: z.number().min(0).max(1),
});

const getLocationsTool = tool(async () => {
  return "Supported locations: Raipur, Delhi, Mumbai";
}, {
  name: "get_locations",
  description: "Get supported event locations",
  schema: z.object({}),
});

async function runTest() {
  const llm = getLLMProvider({ temperature: 0.1 });
  
  // Create a structured output tool
  const submitOutputTool = tool(async (input) => {
    return JSON.stringify(input);
  }, {
    name: "submit_intake_results",
    description: "MUST be called to finalize your response. Call this when you have extracted requirements or need to ask the user a follow-up question.",
    schema: IntakeOutputSchema,
  });

  const tools = [getLocationsTool, submitOutputTool];
  const modelWithTools = llm.bindTools(tools, { tool_choice: "any" }); // Ensure a tool is always called

  const systemPrompt = `You are the Eventology Event Intake Agent.
Extract event requirements from the user.
You can use get_locations to check supported cities.
IMPORTANT: You MUST call the "submit_intake_results" tool to provide your final answer and follow-up question. Do not respond with regular text.`;

  const messages: any[] = [
    new SystemMessage(systemPrompt),
    new HumanMessage("I want a wedding for 200 people. Is Raipur supported?"),
  ];

  let iterations = 0;
  let finalResult: any = null;

  while (iterations < 4) {
    console.log("Iteration", iterations + 1);
    const response = await modelWithTools.invoke(messages) as AIMessage;
    messages.push(response);
    
    if (!response.tool_calls?.length) {
      console.log("No tool calls made, stopping.");
      break;
    }
    
    for (const tc of response.tool_calls) {
      console.log("Called tool:", tc.name);
      if (tc.name === "submit_intake_results") {
        finalResult = tc.args;
        break; // we got our result
      } else if (tc.name === "get_locations") {
        const result = await getLocationsTool.invoke(tc);
        messages.push(new ToolMessage({ content: String(result), tool_call_id: tc.id! }));
      }
    }
    if (finalResult) break;
    iterations++;
  }

  console.log("Final Result:", JSON.stringify(finalResult, null, 2));
}

runTest().catch(console.error);