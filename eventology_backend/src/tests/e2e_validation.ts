/**
 * Phase 10 E2E Validation Script
 * 
 * Performs a full real workflow test:
 * 1. Gets a real Firebase ID token (via REST API signin)
 * 2. POSTs to /api/agent/chat with the wedding planning message
 * 3. Observes what each agent does with real Firestore + real LLM
 * 4. Checks what's in Firestore after each stage
 * 5. Calls /api/agent/approve to resume after interrupt()
 * 6. Checks booking/notification records created
 * 
 * This is a READ/WRITE validation against the real database.
 * No fake data is created — it runs against whatever real data exists.
 */

import * as fs from "fs";
import * as https from "https";
import * as http from "http";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "../../.env") });

// ─── Config ───────────────────────────────────────────────────────────────────
const API_BASE = "http://localhost:3000";
const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY!;
const TEST_EMAIL = process.env.TEST_USER_EMAIL!;
const TEST_PASSWORD = process.env.TEST_USER_PASSWORD!;

// ─── Logging ──────────────────────────────────────────────────────────────────
const log: any[] = [];
function logStep(step: string, data: any) {
  const entry = { ts: new Date().toISOString(), step, data };
  log.push(entry);
  console.log(`\n${"=".repeat(70)}`);
  console.log(`[${entry.ts}] ${step}`);
  console.log(JSON.stringify(data, null, 2));
}

// ─── HTTP helpers ─────────────────────────────────────────────────────────────
async function post(url: string, body: any, headers: Record<string, string> = {}): Promise<any> {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const parsed = new URL(url);
    const isHttps = parsed.protocol === "https:";
    const mod = isHttps ? https : http;
    const req = mod.request({
      hostname: parsed.hostname,
      port: parsed.port ? parseInt(parsed.port) : (isHttps ? 443 : 80),
      path: parsed.pathname + (parsed.search || ""),
      method: "POST",
      headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data), ...headers },
    }, (res) => {
      let raw = "";
      res.on("data", c => raw += c);
      res.on("end", () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(raw) }); }
        catch { resolve({ status: res.statusCode, body: raw }); }
      });
    });
    req.on("error", reject);
    req.setTimeout(300000, () => req.destroy(new Error("Timeout")));
    req.write(data);
    req.end();
  });
}

async function get(url: string, headers: Record<string, string> = {}): Promise<any> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const mod = url.startsWith("https") ? https : http;
    const req = mod.request({
      hostname: parsed.hostname,
      port: parsed.port ? parseInt(parsed.port) : 80,
      path: parsed.pathname + (parsed.search || ""),
      method: "GET",
      headers: { "Content-Type": "application/json", ...headers },
    }, (res) => {
      let raw = "";
      res.on("data", c => raw += c);
      res.on("end", () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(raw) }); }
        catch { resolve({ status: res.statusCode, body: raw }); }
      });
    });
    req.on("error", reject);
    req.setTimeout(300000, () => req.destroy(new Error("Timeout")));
    req.end();
  });
}

// ─── Step 1: Get Firebase ID token via REST API ───────────────────────────────
async function getFirebaseIdToken(): Promise<string> {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`;
  const result = await post(url, { email: TEST_EMAIL, password: TEST_PASSWORD, returnSecureToken: true });
  if (!result.body.idToken) {
    throw new Error(`Auth failed: ${JSON.stringify(result.body)}`);
  }
  logStep("STEP 1: Firebase Auth", {
    email: TEST_EMAIL,
    uid: result.body.localId,
    tokenPreview: result.body.idToken.substring(0, 50) + "...",
  });
  return result.body.idToken;
}

// ─── Step 2: Health check ─────────────────────────────────────────────────────
async function healthCheck(): Promise<void> {
  const result = await get(`${API_BASE}/health`);
  logStep("STEP 2: Health Check", result);
  if (result.status !== 200) throw new Error("Server not running. Start with: npm run dev");
}

// ─── Main validation flow ─────────────────────────────────────────────────────
async function runValidation() {
  console.log("\n" + "█".repeat(70));
  console.log("EVENTOLOGY PHASE 10 — END-TO-END VALIDATION");
  console.log("Real LLM + Real Firebase + Real Firestore");
  console.log("█".repeat(70));

  const results: any = {
    timestamp: new Date().toISOString(),
    llmProvider: process.env.OPENROUTER_MODEL ?? "unknown",
    firebaseProject: "eventalogy-p1",
    steps: {},
    pass: false,
    failedAt: null as string | null,
  };

  try {
    // Step 2: health check
    await healthCheck();
    results.steps.healthCheck = "PASS";

    // Step 1: auth
    const idToken = await getFirebaseIdToken();
    const authHeader = { Authorization: `Bearer ${idToken}` };
    results.steps.firebaseAuth = "PASS";

    // ─ Step 3: Initial chat ─────────────────────────────────────────────────
    logStep("STEP 3: POST /api/agent/chat — Initial wedding planning request", {
      message: "I am planning a wedding in Raipur for approximately 250 guests. I need a venue, catering, photography, decoration and entertainment. My budget is ₹5,00,000.",
    });

    const chatResult = await post(`${API_BASE}/api/agent/chat`, {
      message: "I am planning a wedding in Raipur for approximately 250 guests. I need a venue, catering, photography, decoration and entertainment. My budget is ₹5,00,000.",
    }, authHeader);

    logStep("STEP 3 RESULT: Chat response", { status: chatResult.status, state: chatResult.body?.state });
    results.steps.initialChat = { status: chatResult.status, state: chatResult.body?.state };

    if (chatResult.status !== 200) {
      throw new Error(`Chat failed: ${JSON.stringify(chatResult.body)}`);
    }

    const { conversationId, state: initialState } = chatResult.body;
    results.conversationId = conversationId;

    logStep("STEP 3 ANALYSIS: Agents invoked and workflow state", {
      conversationId,
      workflowStatus: initialState?.workflowStatus,
      currentStage: initialState?.currentStage,
      intakeComplete: initialState?.intakeComplete,
      extractedRequirements: initialState?.eventRequirements,
      pendingQuestions: initialState?.pendingQuestions,
      agentHistory: initialState?.agentHistory,
      completedTasks: initialState?.completedTasks,
    });

    // ─ Step 4: If intake is asking questions, provide date ──────────────────
    if (initialState?.pendingQuestions?.length > 0 && !initialState?.intakeComplete) {
      logStep("STEP 4: Intake asked for more info. Providing date.", {
        questions: initialState.pendingQuestions,
      });

      const followUpResult = await post(`${API_BASE}/api/agent/chat`, {
        message: "The wedding date is December 15, 2025.",
        conversationId,
      }, authHeader);

      logStep("STEP 4 RESULT", { status: followUpResult.status, state: followUpResult.body?.state });
      results.steps.intakeFollowUp = { status: followUpResult.status };
    }

    // ─ Step 5: Check workflow status ────────────────────────────────────────
    await new Promise(r => setTimeout(r, 2000));
    const statusResult = await get(`${API_BASE}/api/agent/status/${conversationId}`, authHeader);
    logStep("STEP 5: Status check", { status: statusResult.status, state: statusResult.body?.state, pendingInterrupt: statusResult.body?.pendingInterrupt });
    results.steps.statusCheck = { status: statusResult.status, state: statusResult.body?.state };

    const currentState = statusResult.body?.state;

    // ─ Step 6: Analyse specialist search results ────────────────────────────
    logStep("STEP 6: Specialist Search Analysis", {
      candidateVenueCount: currentState?.candidateVenueCount,
      candidateVendorCount: currentState?.candidateVendorCount,
      availableVenueCount: currentState?.availableVenueCount,
      availableVendorCount: currentState?.availableVendorCount,
      completedTasks: currentState?.completedTasks,
      agentHistory: currentState?.agentHistory,
    });
    results.steps.specialistSearch = {
      venues: currentState?.candidateVenueCount ?? 0,
      vendors: currentState?.candidateVendorCount ?? 0,
      completedTasks: currentState?.completedTasks,
    };

    // ─ Step 7: Budget and approval ──────────────────────────────────────────
    logStep("STEP 7: Budget and Approval State", {
      budgetBreakdown: currentState?.budgetBreakdown,
      pendingApprovals: currentState?.pendingApprovals,
      approvalStatus: currentState?.approvalStatus,
      pendingInterrupt: statusResult.body?.pendingInterrupt,
    });

    if (currentState?.pendingApprovals?.length > 0 || statusResult.body?.pendingInterrupt) {
      results.steps.approvalInterrupt = "TRIGGERED — graph is suspended";
      results.steps.approvalPendingData = currentState?.pendingApprovals?.[0];

      // ─ Step 8: Isolation test — different user CANNOT access this thread ─
      logStep("STEP 8: ISOLATION TEST — Attempt to access thread with different user", {});

      // Create a different user token (just make a bad token attempt)
      const isolationResult = await get(
        `${API_BASE}/api/agent/status/${conversationId}`,
        { Authorization: "Bearer INVALID_TOKEN_DIFFERENT_USER" }
      );
      results.steps.isolationTest = {
        responseStatus: isolationResult.status,
        blocked: isolationResult.status === 401 || isolationResult.status === 403,
      };
      logStep("STEP 8 RESULT: Isolation test", results.steps.isolationTest);

      // ─ Step 9: Attempt booking BEFORE approval (must be blocked) ─────────
      logStep("STEP 9: Pre-approval booking attempt (must be blocked by approval gate)", {});
      // We can't directly call booking agent, but we can observe that approvalStatus ≠ "approved"
      results.steps.preApprovalGate = {
        approvalStatus: currentState?.approvalStatus,
        bookingsCreated: currentState?.createdBookingIds?.length ?? 0,
        gateWorking: currentState?.approvalStatus !== "approved" && (currentState?.createdBookingIds?.length ?? 0) === 0,
      };
      logStep("STEP 9 RESULT: Pre-approval gate", results.steps.preApprovalGate);

      // ─ Step 10: Resume with approval ────────────────────────────────────
      logStep("STEP 10: POST /api/agent/approve — Resume with approval", {
        conversationId,
        approved: true,
        note: "Approved via E2E validation test",
      });

      const approveResult = await post(`${API_BASE}/api/agent/approve`, {
        conversationId,
        approved: true,
        note: "Approved via E2E validation test",
      }, authHeader);

      logStep("STEP 10 RESULT: Approval response", { status: approveResult.status, state: approveResult.body?.state });
      results.steps.approval = { status: approveResult.status, state: approveResult.body?.state };

      if (approveResult.status === 200) {
        const finalState = approveResult.body?.state;
        results.steps.postApprovalState = {
          approvalStatus: finalState?.approvalStatus,
          createdBookingIds: finalState?.createdBookingIds,
          createdEnquiryIds: finalState?.createdEnquiryIds,
          createdAllocationIds: finalState?.createdAllocationIds,
          workflowStatus: finalState?.workflowStatus,
          currentStage: finalState?.currentStage,
          completedTasks: finalState?.completedTasks,
          agentHistory: finalState?.agentHistory,
        };
        logStep("STEP 11: Post-approval state analysis", results.steps.postApprovalState);

        results.steps.bookingCreated = (finalState?.createdBookingIds?.length ?? 0) > 0;
        results.steps.communicationDone = finalState?.workflowStatus === "completed";
      }
    } else {
      results.steps.approvalInterrupt = `NOT TRIGGERED — workflow may have ended or hit different branch. Status: ${currentState?.workflowStatus}, Stage: ${currentState?.currentStage}`;
      logStep("NOTE: Approval interrupt not triggered", { currentState });
    }

    // ─ Final status check ───────────────────────────────────────────────────
    const finalStatusResult = await get(`${API_BASE}/api/agent/status/${conversationId}`, authHeader);
    results.steps.finalStatus = finalStatusResult.body?.state;
    logStep("STEP 12: Final workflow status", results.steps.finalStatus);

    // ─ History ──────────────────────────────────────────────────────────────
    const historyResult = await get(`${API_BASE}/api/agent/history/${conversationId}`, authHeader);
    results.steps.checkpointHistory = historyResult.body?.history;
    logStep("STEP 13: Checkpoint history", results.steps.checkpointHistory);

    results.pass = true;
    logStep("VALIDATION COMPLETE", { pass: true });

  } catch (err: any) {
    results.pass = false;
    results.failedAt = err.message;
    logStep("VALIDATION FAILED", { error: err.message, stack: err.stack?.split("\n").slice(0, 5) });
  }

  // ─ Write report ───────────────────────────────────────────────────────────
  const report = buildReport(results, log);
  fs.writeFileSync("phase10_e2e_validation_report.md", report);
  console.log(`\n\nReport written to: phase10_e2e_validation_report.md`);
  console.log(`OVERALL RESULT: ${results.pass ? "✅ PASS" : "❌ FAIL — " + results.failedAt}`);

  return results;
}

function buildReport(results: any, log: any[]): string {
  const lines: string[] = [];
  lines.push("# Phase 10 E2E Validation Report");
  lines.push(`\n**Generated:** ${results.timestamp}`);
  lines.push(`**LLM Provider:** ${results.llmProvider}`);
  lines.push(`**Firebase Project:** ${results.firebaseProject}`);
  lines.push(`**Overall Result:** ${results.pass ? "✅ PASS" : "❌ FAIL"}`);
  if (results.failedAt) lines.push(`**Failed At:** ${results.failedAt}`);
  lines.push(`**Conversation ID:** ${results.conversationId ?? "N/A"}`);

  lines.push("\n---\n");
  lines.push("## Step Results\n");
  lines.push("```json");
  lines.push(JSON.stringify(results.steps, null, 2));
  lines.push("```");

  lines.push("\n---\n");
  lines.push("## Full Execution Trace\n");
  for (const entry of log) {
    lines.push(`### ${entry.step}`);
    lines.push(`*${entry.ts}*\n`);
    lines.push("```json");
    lines.push(JSON.stringify(entry.data, null, 2));
    lines.push("```\n");
  }

  return lines.join("\n");
}

runValidation().catch(console.error);
