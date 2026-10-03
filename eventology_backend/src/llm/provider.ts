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
  
  const openRouterApiKey = (process.env.OPENROUTER_API_KEY || "").trim();
  
  // If OpenRouter API key is available, use it as the primary provider
  if (openRouterApiKey) {
    const modelName = options?.modelName || process.env.OPENROUTER_MODEL || "openai/gpt-4o-mini";
    return new ChatOpenAI({
      modelName: modelName,
      temperature,
      apiKey: openRouterApiKey,
      callbacks: options?.callbacks,
      configuration: {
        baseURL: "https://openrouter.ai/api/v1",
        defaultHeaders: {
          "HTTP-Referer": process.env.EVENTOLOGY_WEB_URL || "http://localhost:3000",
          "X-Title": "Eventology AI Agent Runtime"
        }
      }
    });
  }

  // Fallback to Gemini if OpenRouter is not configured
  const geminiApiKey = (process.env.GEMINI_API_KEY || "").trim();
  const geminiModelName = options?.modelName || process.env.GEMINI_MODEL || "gemini-3.8-flash";
  return new ChatGoogleGenerativeAI({
    model: geminiModelName,
    temperature,
    apiKey: geminiApiKey,
    maxRetries: 0,
    callbacks: options?.callbacks,
  });
}
