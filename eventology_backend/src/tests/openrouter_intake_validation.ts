import { eventIntakeAgentNode } from "../agents/event_intake_agent";
import { StateType } from "../graph/state";
import { HumanMessage, AIMessage } from "@langchain/core/messages";
import * as dotenv from "dotenv";
dotenv.config({ override: true });

async function runValidation() {
  let state: any = {
    workflowId: "val_" + Date.now(),
    conversationId: "conv_" + Date.now(),
    currentStage: "intake",
    conversationHistory: [],
    eventRequirements: {},
    missingInformation: [],
    pendingQuestions: [],
    intakeComplete: false,
    retryCount: 0,
    workflowStatus: "active"
  };

  const turns = [
    "I want to organize a wedding.",
    "About 200 people.",
    "In Raipur.",
    "Some time in December. I haven't decided the exact date.",
    "Budget around 5 lakh. I want something elegant.",
    "Actually, make that 300 people."
  ];

  console.log("Starting Real-Model Validation (OpenRouter)");
  console.log("Model:", process.env.OPENROUTER_MODEL);
  console.log("------------------------------------------");

  for (let i = 0; i < turns.length; i++) {
    const userText = turns[i];
    console.log(`\n=== Turn ${i + 1} ===`);
    console.log(`User: ${userText}`);

    // Append to history like the API does
    state.conversationHistory.push(new HumanMessage(userText));

    const result = await eventIntakeAgentNode(state as any);
    
    state = {
      ...state,
      eventRequirements: { ...state.eventRequirements, ...result.eventRequirements },
      missingInformation: result.missingInformation,
      pendingQuestions: result.pendingQuestions,
      conversationHistory: [...state.conversationHistory, ...(result.conversationHistory || [])],
      intakeComplete: result.intakeComplete,
      workflowStatus: result.workflowStatus
    };

    console.log("Requirements:", state.eventRequirements);
    console.log("Missing Info:", state.missingInformation);
    console.log("Next Question:", state.pendingQuestions[0]);
    console.log("Is Complete:", state.intakeComplete);
    console.log("Status:", state.workflowStatus);
  }

  console.log("\n=== Final Conversation History ===");
  state.conversationHistory.forEach((m: any) => {
    const type = m._getType() === "human" ? "Human" : m._getType() === "ai" ? "AI" : "System";
    console.log(`[${type}] ${m.content}`);
  });
}

runValidation().catch(console.error);
