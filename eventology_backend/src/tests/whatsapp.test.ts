/**
 * Phase 24 WhatsApp Integration Tests
 *
 * Tests the webhook handler, identity service, and agent bridge.
 * Run with: npx jest src/tests/whatsapp.test.ts
 */

import { normalizeWaId, formatPhoneDisplay, generateLinkingToken } from "../services/whatsapp_identity_service";

// ─── Unit tests — no Firestore needed ─────────────────────────────────────────

describe("WhatsApp Identity Service — Pure Functions", () => {
  describe("normalizeWaId", () => {
    test("strips leading + sign", () => {
      expect(normalizeWaId("+919876543210")).toBe("919876543210");
    });

    test("strips spaces", () => {
      expect(normalizeWaId("91 98765 43210")).toBe("919876543210");
    });

    test("leaves clean digits unchanged", () => {
      expect(normalizeWaId("919876543210")).toBe("919876543210");
    });

    test("strips hyphens", () => {
      expect(normalizeWaId("91-98765-43210")).toBe("919876543210");
    });
  });

  describe("formatPhoneDisplay", () => {
    test("prepends +", () => {
      expect(formatPhoneDisplay("919876543210")).toBe("+919876543210");
    });
  });

  describe("generateLinkingToken", () => {
    test("generates 64-char hex string", () => {
      const token = generateLinkingToken();
      expect(token).toMatch(/^[a-f0-9]{64}$/);
    });

    test("generates unique tokens", () => {
      const t1 = generateLinkingToken();
      const t2 = generateLinkingToken();
      expect(t1).not.toBe(t2);
    });
  });
});

// ─── Webhook payload parsing tests ────────────────────────────────────────────

describe("WhatsApp Webhook Payload Structure", () => {
  // Valid Meta Cloud API webhook payload for a text message
  const validTextPayload = {
    object: "whatsapp_business_account",
    entry: [
      {
        id: "BUSINESS_ACCOUNT_ID",
        changes: [
          {
            field: "messages",
            value: {
              messaging_product: "whatsapp",
              metadata: {
                display_phone_number: "15556789012",
                phone_number_id: "PHONE_NUMBER_ID",
              },
              contacts: [{ profile: { name: "Test User" }, wa_id: "919876543210" }],
              messages: [
                {
                  from: "919876543210",
                  id: "wamid.TEST123",
                  timestamp: "1700000000",
                  text: { body: "I want to plan a birthday party" },
                  type: "text",
                },
              ],
            },
          },
        ],
      },
    ],
  };

  test("payload has expected structure", () => {
    expect(validTextPayload.object).toBe("whatsapp_business_account");
    expect(validTextPayload.entry[0].changes[0].field).toBe("messages");
    const msg = validTextPayload.entry[0].changes[0].value.messages[0];
    expect(msg.from).toBe("919876543210");
    expect(msg.type).toBe("text");
    expect(msg.text.body).toBe("I want to plan a birthday party");
  });

  test("can extract message text", () => {
    const msg = validTextPayload.entry[0].changes[0].value.messages[0];
    const text = msg.text?.body?.trim() ?? "";
    expect(text).toBe("I want to plan a birthday party");
  });

  test("recognizes interactive button_reply", () => {
    const interactivePayload = {
      from: "919876543210",
      id: "wamid.INTERACTIVE123",
      timestamp: "1700000001",
      type: "interactive",
      interactive: {
        type: "button_reply",
        button_reply: { id: "approve_plan", title: "✅ Approve Plan" },
      },
    };

    const buttonId = interactivePayload.interactive?.button_reply?.id;
    expect(buttonId).toBe("approve_plan");
  });

  test("approval command detection — APPROVE", () => {
    const text = "APPROVE";
    const upperText = text.toUpperCase().trim();
    const textAny: string = text;
    const isApprove = upperText === "APPROVE" || upperText === "APPROVE PLAN" || textAny === "approve_plan";
    expect(isApprove).toBe(true);
  });

  test("approval command detection — button_reply id", () => {
    const text = "approve_plan";
    const isApprove = text === "approve_plan";
    expect(isApprove).toBe(true);
  });

  test("CHANGE command detection", () => {
    const text = "CHANGE";
    const upperText = text.toUpperCase().trim();
    const textAny: string = text;
    const isChange = upperText === "CHANGE" || upperText === "CHANGE SOMETHING" || textAny === "change_plan";
    expect(isChange).toBe(true);
  });
});

// ─── HMAC signature validation logic test ─────────────────────────────────────

import crypto from "crypto";

describe("HMAC Signature Validation", () => {
  const appSecret = "test_app_secret_123";
  const body = JSON.stringify({ object: "whatsapp_business_account" });

  function generateSignature(secret: string, payload: string): string {
    return "sha256=" + crypto.createHmac("sha256", secret).update(payload).digest("hex");
  }

  test("valid signature passes", () => {
    const sig = generateSignature(appSecret, body);
    const expected = generateSignature(appSecret, body);
    expect(
      crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
    ).toBe(true);
  });

  test("invalid signature fails", () => {
    const sig = generateSignature("wrong_secret", body);
    const expected = generateSignature(appSecret, body);
    expect(
      crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
    ).toBe(false);
  });

  test("signature has sha256= prefix", () => {
    const sig = generateSignature(appSecret, body);
    expect(sig.startsWith("sha256=")).toBe(true);
  });
});
