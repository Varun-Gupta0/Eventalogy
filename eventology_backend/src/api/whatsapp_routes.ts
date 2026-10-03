/**
 * WhatsApp Webhook Routes
 *
 * Implements Meta WhatsApp Cloud API webhook integration.
 *
 * Routes:
 *   GET  /api/whatsapp/webhook  — Meta webhook verification challenge
 *   POST /api/whatsapp/webhook  — Incoming messages from Meta
 *   POST /api/whatsapp/link     — Account linking confirmation (called by Flutter web)
 *
 * Security:
 *   - All POST webhook requests validated via HMAC-SHA256 signature
 *   - Identity mapping prevents phone number from being trusted as auth
 *   - Message deduplication prevents replay
 *   - Rate limiting per waId
 *   - Never returns non-200 to Meta (except 403 on verification failure)
 */

import { Router, Request, Response } from "express";
import crypto from "crypto";
import { verifyFirebaseToken } from "../middleware/auth";
import {
  resolveOrCreateIdentity,
  touchIdentity,
  isMessageDuplicate,
  issueLinkingToken,
  linkIdentityToUser,
  normalizeWaId,
} from "../services/whatsapp_identity_service";
import {
  invokeAgentForWhatsApp,
  submitApprovalForWhatsApp,
} from "../services/whatsapp_agent_bridge";
import {
  sendWhatsAppText,
  sendLinkingPrompt,
  sendApprovalPrompt,
  sendErrorMessage,
} from "../services/whatsapp_messaging_service";

const router = Router();

// ─── Per-waId rate limiting (in-memory, production should use Redis) ──────────
const rateLimitMap = new Map<string, { count: number; windowStart: number }>();
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 20; // max 20 messages per minute per waId

function isRateLimited(waId: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(waId);

  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(waId, { count: 1, windowStart: now });
    return false;
  }

  entry.count++;
  if (entry.count > RATE_LIMIT_MAX) {
    return true;
  }
  return false;
}

// ─── HMAC-SHA256 signature validation ─────────────────────────────────────────
function validateWebhookSignature(req: Request): boolean {
  const appSecret = process.env.WHATSAPP_APP_SECRET;
  if (!appSecret) {
    console.error("[WhatsApp] WHATSAPP_APP_SECRET not configured — rejecting all webhooks");
    return false;
  }

  const signature = req.headers["x-hub-signature-256"] as string;
  if (!signature?.startsWith("sha256=")) {
    return false;
  }

  const body = (req as any).rawBody ?? JSON.stringify(req.body);
  const expectedSig =
    "sha256=" + crypto.createHmac("sha256", appSecret).update(body).digest("hex");

  // Constant-time comparison to prevent timing attacks
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSig)
    );
  } catch {
    return false;
  }
}

// ─── GET /api/whatsapp/webhook — Meta verification ────────────────────────────
router.get("/webhook", (req: Request, res: Response) => {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  const verifyToken = process.env.WHATSAPP_VERIFY_TOKEN;
  if (!verifyToken) {
    console.error("[WhatsApp] WHATSAPP_VERIFY_TOKEN not configured");
    return res.status(500).send("Server configuration error");
  }

  if (mode === "subscribe" && token === verifyToken) {
    console.log("[WhatsApp] Webhook verification successful");
    return res.status(200).send(challenge);
  }

  console.warn("[WhatsApp] Webhook verification failed — token mismatch");
  return res.status(403).send("Verification failed");
});

// ─── POST /api/whatsapp/webhook — Incoming messages ───────────────────────────
router.post("/webhook", async (req: Request, res: Response) => {
  // Always respond 200 quickly to Meta — process async
  // EXCEPT for signature failures which return 403

  if (!validateWebhookSignature(req)) {
    console.warn("[WhatsApp] Invalid webhook signature — rejecting");
    return res.status(403).send("Forbidden");
  }

  // Acknowledge immediately (Meta requires < 5s response)
  res.status(200).send("OK");

  // Process async — errors here don't affect the 200 response
  setImmediate(async () => {
    try {
      await processWebhookPayload(req.body);
    } catch (err) {
      console.error("[WhatsApp] Unhandled error in webhook processing:", err);
    }
  });
});

async function processWebhookPayload(body: any): Promise<void> {
  // Validate high-level structure
  if (body?.object !== "whatsapp_business_account") return;

  const entries: any[] = body?.entry ?? [];
  for (const entry of entries) {
    const changes: any[] = entry?.changes ?? [];
    for (const change of changes) {
      if (change?.field !== "messages") continue;
      const value = change?.value;
      await processMessageValue(value);
    }
  }
}

async function processMessageValue(value: any): Promise<void> {
  if (!value?.messages?.length) return; // status updates, etc.

  const messages: any[] = value.messages;

  for (const message of messages) {
    const messageId: string = message.id;
    const waId: string = normalizeWaId(message.from ?? "");
    const timestamp: string = message.timestamp;

    if (!waId || !messageId) continue;

    console.log(`[WhatsApp] Received message ${messageId} from ${waId}`);

    // 1. Rate limit check
    if (isRateLimited(waId)) {
      console.warn(`[WhatsApp] Rate limited: ${waId}`);
      await sendWhatsAppText(
        waId,
        "You're sending messages too quickly. Please wait a moment before trying again."
      );
      continue;
    }

    // 2. Deduplication
    const isDuplicate = await isMessageDuplicate(messageId);
    if (isDuplicate) {
      console.log(`[WhatsApp] Duplicate message ${messageId} — skipping`);
      continue;
    }

    // 3. Extract message text
    const messageType: string = message.type;
    let text = "";

    if (messageType === "text") {
      text = message.text?.body?.trim() ?? "";
    } else if (messageType === "interactive") {
      // Handle button replies
      const buttonReply = message.interactive?.button_reply;
      const listReply = message.interactive?.list_reply;
      text = buttonReply?.id ?? listReply?.id ?? "";
    } else {
      // Unsupported message type
      await sendWhatsAppText(
        waId,
        "Please send a text message. Media and other formats are not supported yet."
      );
      continue;
    }

    if (!text) continue;

    // 4. Resolve/create identity
    const identity = await resolveOrCreateIdentity(waId);

    // 5. Blocked users — silent ignore
    if (identity.status === "blocked") {
      console.log(`[WhatsApp] Blocked identity: ${waId}`);
      continue;
    }

    // 6. Unlinked users — send linking instructions
    if (identity.status === "unlinked" || !identity.userId) {
      const token = await issueLinkingToken(waId);
      await sendLinkingPrompt(waId, token);
      continue;
    }

    // 7. Update lastMessageAt
    await touchIdentity(waId);

    // 8. Handle approval commands
    const upperText = text.toUpperCase().trim();
    const isApproveCommand = upperText === "APPROVE" || upperText === "APPROVE PLAN" || text === "approve_plan";
    const isChangeCommand = upperText === "CHANGE" || upperText === "CHANGE SOMETHING" || text === "change_plan";

    if ((isApproveCommand || isChangeCommand) && identity.conversationId) {
      try {
        const result = await submitApprovalForWhatsApp(
          identity.userId,
          identity.conversationId,
          isApproveCommand
        );
        await sendWhatsAppText(waId, result.responseText);
      } catch (err) {
        console.error(`[WhatsApp] Approval error for ${waId}:`, err);
        await sendErrorMessage(waId);
      }
      continue;
    }

    // 9. Invoke LangGraph agent
    try {
      const result = await invokeAgentForWhatsApp(
        identity.userId,
        waId,
        text,
        identity.conversationId
      );

      // 10. Send response
      if (result.hasPendingApproval && result.approvalSummary) {
        await sendApprovalPrompt(
          waId,
          result.approvalSummary,
          result.approvalTotalCost ?? 0
        );
      } else {
        await sendWhatsAppText(waId, result.responseText);
      }
    } catch (err) {
      console.error(`[WhatsApp] Agent invocation error for ${waId}:`, err);
      await sendErrorMessage(waId);
    }
  }
}

// ─── POST /api/whatsapp/link — Account linking (called from Flutter web) ──────
// Requires: Authorization: Bearer <Firebase ID Token>
// Body: { token: string }  (the linking code the user received on WhatsApp)
router.post("/link", verifyFirebaseToken, async (req: Request, res: Response) => {
  const userId = (req as any).user.uid;
  const { token } = req.body;

  if (!token || typeof token !== "string") {
    return res.status(400).json({ error: "token is required" });
  }

  try {
    const result = await linkIdentityToUser(token, userId);
    if (result.success) {
      console.log(`[WhatsApp] Account linked: userId=${userId}, waId=${result.waId}`);
      return res.json({ success: true, message: "WhatsApp account linked successfully." });
    } else {
      return res.status(400).json({ success: false, error: result.error });
    }
  } catch (err: any) {
    console.error("[WhatsApp] Linking error:", err);
    return res.status(500).json({ error: "Linking failed. Please try again." });
  }
});

// ─── POST /api/whatsapp/initiate-link — Issue a new linking token ──────────────
// Called from Flutter web by an authenticated user who wants to link WhatsApp.
// Body: { phoneNumber: string }
router.post("/initiate-link", verifyFirebaseToken, async (req: Request, res: Response) => {
  const { phoneNumber } = req.body;

  if (!phoneNumber || typeof phoneNumber !== "string") {
    return res.status(400).json({ error: "phoneNumber is required" });
  }

  // Normalize — strip non-digits
  const waId = normalizeWaId(phoneNumber);
  if (waId.length < 10) {
    return res.status(400).json({ error: "Invalid phone number format" });
  }

  try {
    // Ensure identity record exists
    await resolveOrCreateIdentity(waId);
    const token = await issueLinkingToken(waId);

    // Return the token to the user so they can confirm it matches what WhatsApp sent
    return res.json({
      success: true,
      message: `A linking code has been prepared. Please send a message on WhatsApp from +${waId} to receive the code, or enter the code manually.`,
      // Only expose first 8 chars for display — user confirms it matches
      tokenPreview: token.slice(0, 8).toUpperCase(),
    });
  } catch (err: any) {
    console.error("[WhatsApp] Initiate link error:", err);
    return res.status(500).json({ error: "Failed to initiate linking. Please try again." });
  }
});

export default router;
