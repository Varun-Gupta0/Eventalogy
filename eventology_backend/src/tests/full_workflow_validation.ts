import * as dotenv from "dotenv";
dotenv.config({ override: true });

// FORCE OPENROUTER (GPT-4o-mini)
process.env.GEMINI_API_KEY = "";
process.env.OPENROUTER_MODEL = "openai/gpt-4o-mini";
process.env.LANGCHAIN_VERBOSE = "true"; // this will print LLM and Tool invocations to console

import { eventologyAgentApp } from "../graph/index";
import { Command } from "@langchain/langgraph";
import * as fs from "fs";

async function runFullWorkflow() {
  console.log("=== STARTING FULL END-TO-END VALIDATION ===");
  console.log("Model:", process.env.OPENROUTER_MODEL);

  const workflowId = "test_wf_" + Date.now();
  const userId = "test_user";
  const threadId = workflowId;
  const config = { configurable: { thread_id: threadId } };

  // Helper to run graph until pause/end
  async function pumpGraph(input: any | Command) {
    console.log(`\n\n=== PUMPING GRAPH ===`);
    let finalState = null;
    try {
      const stream = await eventologyAgentApp.stream(input, { ...config, streamMode: "updates" });
      for await (const chunk of stream) {
        for (const [nodeName, nodeState] of Object.entries(chunk)) {
          const s = nodeState as any;
          console.log(`\n--- TRANSITION from node: ${nodeName} ---`);
          console.log(`Current Stage: ${s.currentStage}`);
          console.log(`Current Agent: ${s.currentAgent}`);
          console.log(`Workflow Status: ${s.workflowStatus}`);
          console.log(`Completed Tasks:`, s.completedTasks);
          console.log(`Failed Tasks:`, s.failedTasks);
          console.log(`Retry Count:`, s.retryCount);
          if (s.eventRequirements) {
            console.log(`Requirements:`, JSON.stringify(s.eventRequirements));
          }
          if (s.agentHistory && s.agentHistory.length > 0) {
            console.log(`Last Agent History Note:`, s.agentHistory[s.agentHistory.length - 1].notes);
          }
          finalState = s;
        }
      }
    } catch (err: any) {
      if (err?.name === "GraphInterrupt") {
        console.log("\n--- GRAPH INTERRUPTED ---");
        const graphState = await eventologyAgentApp.getState(config);
        finalState = graphState.values;
      } else {
        throw err;
      }
    }
    
    // Also fetch current full state to ensure we have the latest
    const graphState = await eventologyAgentApp.getState(config);
    return graphState;
  }

  // Turn 1
  console.log("\n=== TURN 1: Initial User Input ===");
  const input1 = {
    workflowId,
    conversationId: threadId,
    userId,
    eventId: "test_event_id",
    userMessage: "I want to organize a wedding in Raipur.",
  };
  
  let graphState = await pumpGraph(input1);

  // Turn 2
  console.log("\n=== TURN 2: Responding to Agent (Mixed Language & Correction) ===");
  graphState = await pumpGraph({
    userMessage: "Make that 300 guests. Budget lagbhag 5 lakh hai, aur venue thoda premium aur elegant chahiye.",
  });

  // Keep resolving if stuck in intake
  let sanityLimit = 5;
  while (graphState.values.workflowStatus === "pending_user" && graphState.values.currentStage === "intake" && sanityLimit > 0) {
    console.log("\n=== TURN N: Resolving remaining intake ===");
    graphState = await pumpGraph({ userMessage: "Any date in December 2026 is fine. Need Catering, Decor and Photography." });
    sanityLimit--;
  }

  console.log("\n=== WAITING FOR GRAPH TO REACH APPROVAL ===");
  // Note: We might need to send a null input to continue if it stopped at orchestrator?
  // LangGraph nodes continue automatically until END or interrupt.
  
  if (graphState.next && graphState.next.length > 0) {
    if (graphState.next[0] === "approval_agent" || graphState.tasks?.some((t: any) => t.name === "approval_agent" && t.interrupts?.length > 0)) {
      console.log("\n=== RESUMING FROM INTERRUPT (APPROVAL) ===");
      graphState = await pumpGraph(
        new Command({ resume: { approved: true, note: "Looks perfect, proceed." } })
      );
    }
  }

  console.log("\n=== FINAL STATE ===");
  console.log(JSON.stringify(graphState.values, null, 2));
  
  if (graphState.values.workflowStatus === "completed" || graphState.values.workflowStatus === "active") {
    console.log("\n✅ END-TO-END VALIDATION: PASS");
  } else {
    console.log("\n❌ END-TO-END VALIDATION: FAIL");
  }
}

runFullWorkflow().catch(console.error);
