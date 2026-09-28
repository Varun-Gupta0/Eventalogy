import * as dotenv from "dotenv";
import * as path from "path";
import { z } from "zod";
import { tool } from "@langchain/core/tools";
import { getLLMProvider } from "../llm/provider";
import { SystemMessage, HumanMessage } from "@langchain/core/messages";

// Ensure environment variables are loaded securely
dotenv.config({ path: path.join(__dirname, "../../.env"), override: true });

// Define a test schema
const testSchema = z.object({
  status: z.string().describe("The status of the extraction, should be 'SUCCESS'"),
  confidence: z.number().describe("A confidence score between 0 and 100"),
  extractedValues: z.array(z.string()).describe("A list of extracted important terms from the input text")
});

// Define a dummy tool
const weatherTool = tool(
  async ({ location }) => {
    return `The weather in ${location} is sunny.`;
  },
  {
    name: "get_weather",
    description: "Get the current weather in a given location",
    schema: z.object({
      location: z.string().describe("The city and state, e.g., San Francisco, CA"),
    }),
  }
);

async function runGeminiTest() {
  console.log(`\n======================================================`);
  console.log(`Testing Gemini Provider Integration`);
  console.log(`======================================================\n`);
  
  if (!process.env.GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is missing from environment variables.");
    process.exit(1);
  }

  try {
    const llm = getLLMProvider({ temperature: 0 });

    // Test 1: Normal Generation (Authentication & Basic connectivity)
    console.log(`[Test 1] Normal Text Generation & Auth...`);
    try {
      const res1 = await llm.invoke("Reply with exactly: EVENTOLOGY_LLM_OK");
      const content = typeof res1.content === "string" ? res1.content.trim() : JSON.stringify(res1.content);
      
      if (content.includes("EVENTOLOGY_LLM_OK")) {
        console.log(`✅ GEMINI_AUTH_OK`);
        console.log(`✅ GEMINI_MODEL_OK`);
      } else {
        console.log(`❌ FAIL: Unexpected output: ${content}`);
      }
    } catch (e: any) {
      console.error(`❌ GEMINI_AUTH_FAIL: ${e.message}`);
      return;
    }

    // Test 2: Structured JSON Output
    console.log(`\n[Test 2] Structured Output with Zod Schema...`);
    try {
      const structuredLlm = llm.withStructuredOutput(testSchema);
      const res2 = await structuredLlm.invoke([
        new SystemMessage("You are a helpful assistant. Extract information exactly according to the schema."),
        new HumanMessage("Please extract information from this text: The mission is a SUCCESS. I am 99% confident. The key terms are apple, banana, and cherry.")
      ]);
      
      if (res2 && res2.status === "SUCCESS" && res2.extractedValues && res2.extractedValues.length > 0) {
        console.log(`✅ GEMINI_STRUCTURED_OUTPUT_OK`);
      } else {
        console.log(`❌ FAIL (Invalid schema match): ${JSON.stringify(res2)}`);
      }
    } catch (e: any) {
      console.error(`❌ GEMINI_STRUCTURED_OUTPUT_FAIL: ${e.message}`);
    }

    // Test 3: Tool Calling
    console.log(`\n[Test 3] Native Tool/Function Calling...`);
    try {
      const llmWithTools = llm.bindTools([weatherTool]);
      const res3 = await llmWithTools.invoke([
        new HumanMessage("What is the weather in Raipur, Chhattisgarh?")
      ]);
      
      if (res3.tool_calls && res3.tool_calls.length > 0) {
        const toolCall = res3.tool_calls[0];
        
        if (toolCall.name === "get_weather" && toolCall.args.location) {
          console.log(`✅ GEMINI_TOOL_CALLING_OK`);
        } else {
          console.log(`❌ FAIL (Incorrect tool or arguments)`);
        }
      } else {
        console.log(`❌ FAIL (No tool calls detected)`);
      }
    } catch (e: any) {
      console.error(`❌ GEMINI_TOOL_CALLING_FAIL: ${e.message}`);
    }

  } catch (e: any) {
    console.error(`Fatal error: ${e.message}`);
  }
}

runGeminiTest().catch(console.error);
