import * as dotenv from "dotenv";
import * as path from "path";
import { z } from "zod";
import { tool } from "@langchain/core/tools";
import { getLLMProvider } from "../llm/provider";
import { SystemMessage, HumanMessage } from "@langchain/core/messages";
import * as fs from "fs";

// Ensure environment variables are loaded securely
dotenv.config({ path: path.join(__dirname, "../../.env"), override: true });

const MODELS_TO_TEST = [
  "nvidia/nemotron-3-ultra-550b-a55b:free",
  "qwen/qwen3.8-27b:free",
  "google/gemma-4-31b-it:free",
  "nvidia/nemotron-3-super-120b-a12b:free"
];

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

interface ModelResult {
  model: string;
  authenticationResult: string;
  normalGeneration: string;
  structuredOutput: string;
  toolCalling: string;
  averageLatencyMs: number;
  failureReason: string | null;
  productionSuitable: boolean;
}

async function delay(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function testModel(modelName: string): Promise<ModelResult> {
  console.log(`\n======================================================`);
  console.log(`Testing Model: ${modelName}`);
  console.log(`======================================================`);
  
  // Override environment variable dynamically for provider factory
  process.env.OPENROUTER_MODEL = modelName;
  
  const result: ModelResult = {
    model: modelName,
    authenticationResult: "FAIL",
    normalGeneration: "FAIL",
    structuredOutput: "FAIL",
    toolCalling: "FAIL",
    averageLatencyMs: 0,
    failureReason: null,
    productionSuitable: false
  };

  let totalLatency = 0;
  let testCount = 0;

  try {
    const llm = getLLMProvider({ temperature: 0 });

    // Test 1: Normal Generation (Authentication & Basic connectivity)
    console.log(`\n[Test 1] Normal Text Generation & Auth...`);
    const start1 = Date.now();
    try {
      const res1 = await llm.invoke("Reply with exactly: EVENTOLOGY_LLM_OK");
      const latency1 = Date.now() - start1;
      totalLatency += latency1;
      testCount++;
      
      const content = typeof res1.content === "string" ? res1.content.trim() : JSON.stringify(res1.content);
      console.log(`  Latency: ${latency1}ms | Response: ${content}`);
      
      if (content.includes("EVENTOLOGY_LLM_OK")) {
        result.authenticationResult = "PASS";
        result.normalGeneration = "PASS";
      } else {
        result.normalGeneration = "FAIL (Unexpected output)";
      }
    } catch (e: any) {
      console.log(`  Error in normal generation: ${e.message}`);
      result.authenticationResult = "FAIL (Auth or Network)";
      result.failureReason = `Generation Failed: ${e.message}`;
      return result; // Stop testing this model if basic auth/generation fails
    }

    // Wait slightly to avoid free-tier strict rate limits
    await delay(3000);

    // Test 2: Structured JSON Output
    console.log(`\n[Test 2] Structured Output with Zod Schema...`);
    const start2 = Date.now();
    try {
      const structuredLlm = llm.withStructuredOutput(testSchema);
      
      const res2 = await structuredLlm.invoke([
        new SystemMessage("You are a helpful assistant. Extract information exactly according to the schema."),
        new HumanMessage("Please extract information from this text: The mission is a SUCCESS. I am 99% confident. The key terms are apple, banana, and cherry.")
      ]);
      
      const latency2 = Date.now() - start2;
      totalLatency += latency2;
      testCount++;
      
      console.log(`  Latency: ${latency2}ms | Output:`, JSON.stringify(res2));
      
      if (res2 && res2.status && res2.extractedValues && res2.extractedValues.length > 0) {
        result.structuredOutput = "PASS";
      } else {
        result.structuredOutput = "FAIL (Invalid schema match)";
        result.failureReason = "Structured output did not match Zod schema perfectly";
      }
    } catch (e: any) {
      const latency2 = Date.now() - start2;
      console.log(`  Latency: ${latency2}ms | Error in structured output: ${e.message}`);
      result.structuredOutput = `FAIL (${e.message.substring(0, 50)}...)`;
      if (!result.failureReason) result.failureReason = `Structured Parsing Error: ${e.message}`;
    }

    // Wait slightly to avoid free-tier strict rate limits
    await delay(3000);

    // Test 3: Tool Calling
    console.log(`\n[Test 3] Native Tool/Function Calling...`);
    const start3 = Date.now();
    try {
      const llmWithTools = llm.bindTools([weatherTool]);
      const res3 = await llmWithTools.invoke([
        new HumanMessage("What is the weather in Raipur, Chhattisgarh?")
      ]);
      
      const latency3 = Date.now() - start3;
      totalLatency += latency3;
      testCount++;
      
      console.log(`  Latency: ${latency3}ms | Tool Calls length: ${res3.tool_calls?.length || 0}`);
      
      if (res3.tool_calls && res3.tool_calls.length > 0) {
        const toolCall = res3.tool_calls[0];
        console.log(`  Called Tool: ${toolCall.name} with args:`, toolCall.args);
        
        if (toolCall.name === "get_weather" && toolCall.args.location) {
          result.toolCalling = "PASS";
        } else {
          result.toolCalling = "FAIL (Incorrect tool or arguments)";
          if (!result.failureReason) result.failureReason = "Tool calling produced incorrect tool or arguments";
        }
      } else {
        result.toolCalling = "FAIL (No tool calls detected)";
        if (!result.failureReason) result.failureReason = "Model did not trigger the provided tool";
      }
    } catch (e: any) {
      const latency3 = Date.now() - start3;
      console.log(`  Latency: ${latency3}ms | Error in tool calling: ${e.message}`);
      result.toolCalling = `FAIL (${e.message.substring(0, 50)}...)`;
      if (!result.failureReason) result.failureReason = `Tool Calling Error: ${e.message}`;
    }

  } catch (e: any) {
    console.error(`Unexpected fatal error during testing of ${modelName}:`, e);
    result.failureReason = `Fatal error: ${e.message}`;
  }

  if (testCount > 0) {
    result.averageLatencyMs = Math.round(totalLatency / testCount);
  }

  // Determine production suitability
  if (result.authenticationResult === "PASS" && result.structuredOutput === "PASS" && result.toolCalling === "PASS") {
    result.productionSuitable = true;
  }

  console.log(`\n[RESULT for ${modelName}]`);
  console.log(`  Auth: ${result.authenticationResult}`);
  console.log(`  Normal: ${result.normalGeneration}`);
  console.log(`  Structured: ${result.structuredOutput}`);
  console.log(`  Tooling: ${result.toolCalling}`);
  console.log(`  Suitable: ${result.productionSuitable ? 'YES' : 'NO'}`);
  
  return result;
}

async function runTests() {
  console.log("Starting Model Compatibility Audit...");
  
  const results: ModelResult[] = [];
  
  for (const model of MODELS_TO_TEST) {
    const res = await testModel(model);
    results.push(res);
    // Cool down between models to avoid OpenRouter rate limits
    await delay(3000);
  }
  
  console.log(`\n\n======================================================`);
  console.log(`AUDIT COMPLETE`);
  console.log(`======================================================\n`);
  
  const reportPath = path.join(__dirname, "../../../model_compatibility_report.json");
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  console.log(`Saved detailed JSON results to ${reportPath}`);
}

runTests().catch(console.error);
