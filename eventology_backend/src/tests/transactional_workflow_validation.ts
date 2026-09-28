import * as dotenv from "dotenv";
dotenv.config({ override: true });

process.env.LANGCHAIN_VERBOSE = "false"; // Keep concise for this test

import { eventologyAgentApp } from "../graph/index";
import { Command } from "@langchain/langgraph";

async function simulateTransactionalFlow(testName: string, threadId: string, approvalDecision: boolean, shouldFailBooking: boolean = false) {
  console.log(`\n]======================================================`);
  console.log(`=== STARTING TEST: ${testName} ===`);
  console.log(`]======================================================\n`);

  const workflowId = "txn_wf_" + Date.now();
  const userId = "test_txn_user";
  const eventId = "test_txn_event";
  const config = { configurable: { thread_id: threadId } };

  // Helper to run graph
  async function pumpGraph(input: any | Command) {
    console.log(`\n[Pumping Graph]...`);
    let finalState = null;
    try {
      const stream = await eventologyAgentApp.stream(input, { ...config, streamMode: "updates" });
      for await (const chunk of stream) {
        for (const [nodeName, nodeState] of Object.entries(chunk)) {
          const s = nodeState as any;
          console.log(`  -> Node: ${nodeName} | Stage: ${s.currentStage} | Status: ${s.workflowStatus}`);
          if (s.agentHistory?.length > 0) {
            console.log(`     Note: ${s.agentHistory[s.agentHistory.length - 1].notes}`);
          }
        }
      }
    } catch (err: any) {
      if (err?.name === "GraphInterrupt") {
        console.log("  -> GRAPH INTERRUPTED (Approval Required)");
      } else {
        throw err;
      }
    }
    
    return await eventologyAgentApp.getState(config);
  }

  // Initial State Injection
  const mockInitialState = {
    workflowId,
    conversationId: threadId,
    userId,
    eventId,
    currentStage: "budget", // the orchestrator will see this
    intakeComplete: true,
    eventRequirements: {
      eventType: "Corporate Event",
      location: "Mumbai",
      guestCount: 200,
      dateStr: "2026-12-10",
    },
    eventPlan: {
      title: "Mumbai Corporate Gala",
      summary: "A premium corporate event.",
      requiredServices: ["Catering", "AV Setup"],
      venueCharacteristics: ["Premium", "Indoor"],
      estimatedInitialBudget: 1000000,
      dependencies: [],
    },
    completedTasks: ["event_intake_agent", "event_planning_agent", "venue_agent", "vendor_agent", "service_agent", "availability_agent", "budget_agent"],
    candidateVenues: [{ venueId: "venue_1", name: "Taj Mumbai", city: "Mumbai", capacity: 500, venueType: "Hotel" }],
    candidateVendors: [{ vendorId: "vendor_1", name: "Premium Caterers", serviceCategory: "Catering", city: "Mumbai" }],
    selectedVenueId: "venue_1",
    selectedVendorIds: ["vendor_1"],
    availableVenueIds: ["venue_1"],
    availableVendorIds: ["vendor_1"],
    budgetBreakdown: {
      totalEstimatedCost: 800000,
      lineItems: [
        { category: "Venue", venueId: "venue_1", description: "Base rental", estimatedCost: 500000 },
        { category: "Catering", vendorId: "vendor_1", description: "Food", estimatedCost: 300000 },
      ],
      withinBudget: true,
      notes: "Looks good",
    },
    budgetSufficient: true,
    approvalStatus: "none",
  };

  let graphState = await pumpGraph(mockInitialState);

  const pendingTask = graphState.tasks?.find((t: any) => t.interrupts?.length > 0);
  if (!pendingTask || pendingTask.name !== "approval_agent") {
    console.error("∜ FAILED: Did not reach approval interrupt.");
    console.log("Current State:", graphState.values);
    return false;
  }

  console.log(`\n[Resuming] Approving = ${approvalDecision}`);
  graphState = await pumpGraph(
    new Command({ resume: { approved: approvalDecision, note: approvalDecision ? "Looks perfect, approved." : "Too expensive, rejected." } })
  );

  const finalVals = graphState.values;
  
  if (!approvalDecision) {
    if (finalVals.workflowStatus === "completed" && finalVals.approvalStatus === "rejected") {
      console.log("⎥ SUCCESS: Workflow correctly terminated after rejection.");
      return true;
    } else {
      console.error("∜ FAILED: Expected completed/rejected status.");
      return false;
    }
  }

  const bookingsCreated = finalVals.createdBookingIds?.length > 0;
  const commsCompleted = finalVals.completedTasks?.includes("communication_agent");

  if (bookingsCreated && commsCompleted && finalVals.workflowStatus === "completed") {
    console.log("⎬ SUCCESS: Workflow correctly booked and communicated.");
    return true;
  } else {
    console.error("∜ FAILED: Booking or Communication did not complete properly.");
    console.log("Final State Tasks:", finalVals.completedTasks);
    console.log("Final Workflow Status:", finalVals.workflowStatus);
    return false;
  }
}

async function runAllTests() {
  const t1 = await simulateTransactionalFlow("SUCCESS_PATH", "thread_" + Date.now(), true);
  const t2 = await simulateTransactionalFlow("REJECTION_PATH", "thread_" + Date.now(), false);
  
  console.log("\n]======================================================");
  console.log("=== RESUME IDEMPOTENCY TEST ===");
  console.log("]======================================================\n");
  const resumeThreadId = "thread_resume_" + Date.now();
  await simulateTransactionalFlow("RESUME_STEP_1", resumeThreadId, true);
  
  console.log("\n[Re-running graph on SAME THREAD to simulate duplicate trigger]");
  const config = { configurable: { thread_id: resumeThreadId } };
  const graphState = await eventologyAgentApp.getState(config);
  
  let stream = await eventologyAgentApp.stream({ workflowStatus: "active" }, { ...config, streamMode: "updates" });
  for await (const chunk of stream) {
    for (const [nodeName, nodeState] of Object.entries(chunk)) {
      console.log(`  -> Node: ${nodeName} | Status: ${(nodeState as any).workflowStatus}`);
    }
  }
  
  const finalState = await eventologyAgentApp.getState(config);
  const isIdempotent = finalState.values.createdBookingIds.length === 1; // shouldn't have doubled
  if (isIdempotent) {
    console.log("⎥ SUCCESS: Booking Idempotency Verified.");
  } else {
    console.error("∜ FAILED: Bookings were duplicated!", finalState.values.createdBookingIds);
  }

  console.log("\nTest run completed.");
  process.exit(0);
}

runAllTests().catch(console.error);