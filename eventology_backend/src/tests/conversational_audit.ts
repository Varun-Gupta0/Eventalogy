import { HumanMessage, AIMessage } from "@langchain/core/messages";
import { orchestratorAgentNode } from "../agents/orchestrator_agent";
import { StateType } from "../graph/state";
import { getLLMProvider } from "../llm/provider";

async function runConversationalAudit() {
  console.log("==========================================");
  console.log("   CONVERSATIONAL REASSESSMENT AUDIT      ");
  console.log("==========================================\n");

  const baseRequirements = {
    eventType: "Birthday",
    guestCount: 50,
    location: "Raipur",
    dateStr: "2026-10-10",
  };

  const createBaseState = (
    userMessage: string,
    history: any[] = [],
    createdBookings = false,
    approvalStatus: "none" | "pending" | "approved" | "rejected" = "none"
  ): Partial<StateType> => {
    return {
      workflowId: "test-audit-wf",
      conversationId: "test-audit-conv",
      userId: "test-user",
      currentStage: "intake",
      currentAgent: "orchestrator_agent",
      userMessage,
      conversationHistory: history,
      eventRequirements: { ...baseRequirements },
      intakeComplete: true,
      eventPlan: { title: "Party Plan", summary: "...", requiredServices: [], venueCharacteristics: [], estimatedInitialBudget: 1000, dependencies: [] },
      aiPlanId: "plan-123",
      completedTasks: ["event_intake_agent", "event_planning_agent"],
      workflowStatus: "active",
      createdBookingIds: createdBookings ? ["bk-123"] : [],
      approvalStatus,
    };
  };

  const runTest = async (name: string, userMessage: string, createdBookings = false, approvalStatus: "none" | "approved" = "none") => {
    console.log(`\n▶ TEST: ${name}`);
    console.log(`  USER: "${userMessage}"`);
    console.log(`  BOOKINGS: ${createdBookings ? "YES" : "NO"} | APPROVAL: ${approvalStatus}`);
    
    const state = createBaseState(userMessage, [], createdBookings, approvalStatus);
    const updates = await orchestratorAgentNode(state as StateType);
    
    console.log("  [RESULTS]");
    if (updates.eventRequirements) {
      console.log("  - Updated Requirements: ", JSON.stringify(updates.eventRequirements));
    }
    
    const invalidated = [];
    if (updates.intakeComplete === false) invalidated.push("intake");
    if (updates.eventPlan === null) invalidated.push("planning");
    if (updates.approvalStatus === "none" && approvalStatus === "approved") invalidated.push("approval");
    
    if (invalidated.length > 0) {
      console.log("  - Invalidated Stages: ", invalidated.join(", "));
    }
    
    if (updates.conversationHistory && updates.conversationHistory.length > 1) {
      const msg = updates.conversationHistory[1] as AIMessage;
      console.log("  - AI Reply: ", msg.content);
    }
    
    console.log("  - Next Agent: ", updates.currentAgent);
    console.log("------------------------------------------");
  };

  // 1. new requirement after intake
  await runTest("new requirement after intake", "I also need a DJ.");
  
  // 2. changing guest count
  await runTest("changing guest count", "Actually, we need space for 150 people now.");
  
  // 3. changing event type
  await runTest("changing event type", "It's no longer a birthday, it's going to be a corporate event.");
  
  // 4. changing budget
  await runTest("changing budget", "My budget just increased to 5 lakhs.");
  
  // 5. changing location
  await runTest("changing location", "We decided to host it in Delhi instead of Raipur.");
  
  // 6. changing multiple requirements in one message
  await runTest("changing multiple requirements in one message", "Change it to a wedding for 300 guests in Mumbai.");
  
  // 7. user providing unrelated information
  await runTest("user providing unrelated information", "My dog's name is Rex and he likes bones.");
  
  // 8. user asking a question rather than changing requirements
  await runTest("user asking a question rather than changing requirements", "What time do vendors usually arrive?");
  
  // 9. modification after approval but before booking
  await runTest("modification after approval but before booking", "Actually, increase the guest count to 100.", false, "approved");
  
  // 10. modification after booking
  await runTest("modification after booking", "Actually, increase the guest count to 100.", true, "approved");
}

runConversationalAudit().catch(console.error);
