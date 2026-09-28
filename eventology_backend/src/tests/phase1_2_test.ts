import * as dotenv from "dotenv";
import * as path from "path";
import { getLLMProvider } from "../llm/provider";
import { HumanMessage } from "@langchain/core/messages";

dotenv.config({ path: path.join(__dirname, "../../.env"), override: true });

async function run() {
  console.log("==================================================");
  console.log("PHASE 1 — VERIFY ENVIRONMENT");
  console.log("==================================================");

  const apiKey = process.env.OPENROUTER_API_KEY;
  const model = process.env.OPENROUTER_MODEL;

  if (!apiKey) {
    console.error("FAIL: OPENROUTER_API_KEY is missing from environment.");
    process.exit(1);
  }
  if (!model) {
    console.error("FAIL: OPENROUTER_MODEL is missing from environment.");
    process.exit(1);
  }

  console.log("OpenRouter key: configured");
  console.log(`Model: ${model}`);

  console.log("\n==================================================");
  console.log("PHASE 2 — DIRECT LLM CONNECTIVITY TEST");
  console.log("==================================================");

  try {
    const llm = getLLMProvider();
    
    // Check if provider is actually picking up the model
    // @ts-ignore - internal property access for test verification
    const configuredModel = llm.model || (llm as any).modelName;
    if (configuredModel !== model) {
      console.error(`FAIL: LLM provider is using model '${configuredModel}', expected '${model}'.`);
      process.exit(1);
    }
    
    console.log(`Testing direct connectivity to OpenRouter using ${configuredModel}...`);
    
    const response = await llm.invoke([
      new HumanMessage("Reply with exactly EVENTOLOGY_LLM_OK")
    ]);
    
    console.log("\nResponse from LLM:");
    console.log(response.content);
    
    if (typeof response.content === "string" && response.content.includes("EVENTOLOGY_LLM_OK")) {
      console.log("\n✅ PHASE 2 PASS: Connectivity established and LLM returned expected response.");
    } else {
      console.log("\n⚠️ PHASE 2 WARNING: LLM responded but did not follow exact instructions.");
    }
    
  } catch (err: any) {
    console.error("\n❌ PHASE 2 FAIL: Error connecting to OpenRouter LLM");
    console.error(`Error details: ${err.message}`);
    if (err.response?.data) {
      console.error(JSON.stringify(err.response.data, null, 2));
    }
    process.exit(1);
  }
}

run().catch(console.error);
