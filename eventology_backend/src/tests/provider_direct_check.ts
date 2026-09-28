import { getLLMProvider } from "../llm/provider";
import { z } from "zod";
import * as dotenv from "dotenv";

dotenv.config({ override: true });

async function runProviderCheck() {
  console.log("=== PROVIDER DIRECT CHECK ===");
  console.log("Configured Provider logic: GEMINI_API_KEY =", process.env.GEMINI_API_KEY ? "Present" : "Missing");
  console.log("Configured GEMINI_MODEL =", process.env.GEMINI_MODEL);
  console.log("Configured OPENROUTER_MODEL =", process.env.OPENROUTER_MODEL);

  const llm = getLLMProvider();
  console.log("LLM Instance created:", llm.constructor.name);

  // Test 1: Simple text generation
  console.log("\n1. Testing Simple Text Generation...");
  try {
    const res = await llm.invoke("Hello, respond with 'OK' if working.");
    console.log("Response:", res.content);
    console.log("Simple Text Generation: PASS");
  } catch (err: any) {
    console.error("Simple Text Generation Failed:");
    console.error("Status/Message:", err.message || err);
    if (err.status) console.error("Status code:", err.status);
  }

  // Test 2: Structured Output Compatibility
  console.log("\n2. Testing Structured Output Compatibility...");
  try {
    const Schema = z.object({
      status: z.string().describe("Status string"),
      greeting: z.string().describe("Greeting text")
    });
    const structuredLlm = llm.withStructuredOutput(Schema);
    const res = await structuredLlm.invoke("Say hello to Eventology.");
    console.log("Structured Response:", JSON.stringify(res, null, 2));
    console.log("Structured Output: PASS");
  } catch (err: any) {
    console.error("Structured Output Failed:");
    console.error("Status/Message:", err.message || err);
  }

  // Test 3: Tool / Function Calling Compatibility
  console.log("\n3. Testing Tool Binding Compatibility...");
  try {
    const toolSchema = {
      name: "get_weather",
      description: "Get weather for a city",
      parameters: {
        type: "object",
        properties: {
          location: { type: "string" }
        },
        required: ["location"]
      }
    };
    const llmWithTools = llm.bindTools([toolSchema]);
    const res = await llmWithTools.invoke("What is the weather in Raipur?");
    console.log("Tool Response tool_calls:", JSON.stringify(res.tool_calls, null, 2));
    console.log("Tool Binding: PASS");
  } catch (err: any) {
    console.error("Tool Binding Failed:");
    console.error("Status/Message:", err.message || err);
  }
}

runProviderCheck().catch(console.error);
