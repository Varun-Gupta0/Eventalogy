import { ChatGoogleGenerativeAI } from "@langchain/google-genai";
import { ChatOpenAI } from "@langchain/openai";
import * as dotenv from "dotenv";

dotenv.config({ override: true });
process.env.LANGCHAIN_VERBOSE = "true";

export interface LLMProviderOptions {
  temperature?: number;
  modelName?: string;
  callbacks?: any[];
}

export function getLLMProvider(options?: LLMProviderOptions) {
  const temperature = options?.temperature ?? 0.0;
  
  const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();

  // If Gemini API key is available, use Gemini as the primary provider
  if (geminiApiKey) {
    const modelName = options?.modelName || process.env.GEMINI_MODEL || "gemini-3.8-flash";
    return new ChatGoogleGenerativeAI({
      model: modelName,
      temperature,
      apiKey: geminiApiKey,
      maxRetries: 0,
      callbacks: options?.callbacks,
    });
  }

  // Fallback to OpenRouter if Gemini is not configured
  const modelName = options?.modelName || process.env.OPENROUTER_MODEL || "meta-llama/llama-3.1-8b-instruct:free";
  const openRouterApiKey = (process.env.OPENROUTER_API_KEY || "").trim();
  
  return new ChatOpenAI({
    modelName: modelName,
    temperature,
    apiKey: openRouterApiKey,
    callbacks: options?.callbacks,
    configuration: {
      baseURL: "https://openrouter.ai/api/v1",
      defaultHeaders: {
        "HTTP-Referer": "http://localhost:3000",
        "X-Title": "Eventology AI Agent Runtime"
      }
    }
  });
}
