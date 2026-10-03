import axios from "axios";

const BASE_URL = "https://graph.facebook.com/v20.0";

function getPhoneNumberId(): string {
  const id = process.env.WHATSAPP_PHONE_NUMBER_ID;
  if (!id) throw new Error("WHATSAPP_PHONE_NUMBER_ID is not configured");
  return id;
}

function getAccessToken(): string {
  const token = process.env.WHATSAPP_ACCESS_TOKEN;
  if (!token) throw new Error("WHATSAPP_ACCESS_TOKEN is not configured");
  return token;
}

/**
 * Send a plain text message to a WhatsApp user.
 */
export async function sendWhatsAppText(to: string, text: string): Promise<void> {
  const phoneNumberId = getPhoneNumberId();
  const accessToken = getAccessToken();

  // WhatsApp has a 4096 character limit per message
  const chunks = splitIntoChunks(text, 4000);

  for (const chunk of chunks) {
    await axios.post(
      `${BASE_URL}/${phoneNumberId}/messages`,
      {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to,
        type: "text",
        text: { body: chunk, preview_url: false },
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        timeout: 10000,
      }
    );
  }
}

/**
 * Send an approval prompt with reply buttons when the AI has a pending approval.
 * Falls back to plain text if Meta buttons are unavailable.
 */
export async function sendApprovalPrompt(
  to: string,
  summary: string,
  totalCost: number
): Promise<void> {
  const phoneNumberId = getPhoneNumberId();
  const accessToken = getAccessToken();

  const bodyText =
    `${summary}\n\n` +
    `💰 *Estimated Total: ₹${totalCost.toLocaleString("en-IN")}*\n\n` +
    `Would you like to approve this plan?\n\n` +
    `Reply *APPROVE* to confirm, or *CHANGE* to modify something.`;

  try {
    // Attempt interactive button message
    await axios.post(
      `${BASE_URL}/${phoneNumberId}/messages`,
      {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: bodyText },
          action: {
            buttons: [
              { type: "reply", reply: { id: "approve_plan", title: "✅ Approve Plan" } },
              { type: "reply", reply: { id: "change_plan", title: "✏️ Change Something" } },
            ],
          },
        },
      },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        timeout: 10000,
      }
    );
  } catch {
    // Fallback to plain text if interactive message fails
    await sendWhatsAppText(to, bodyText);
  }
}

/**
 * Send an account-linking prompt to an unlinked user.
 */
export async function sendLinkingPrompt(to: string, token: string): Promise<void> {
  const webUrl = process.env.EVENTOLOGY_WEB_URL ?? "http://localhost:3001";
  const linkUrl = `${webUrl}/link-whatsapp?code=${token}`;

  const text =
    `👋 Welcome to *Eventology*!\n\n` +
    `To use our AI event planning service on WhatsApp, please link your account:\n\n` +
    `🔗 ${linkUrl}\n\n` +
    `Or visit Eventology on the web and go to *Profile → Link WhatsApp* and enter this code:\n\n` +
    `*${token.slice(0, 8).toUpperCase()}*\n\n` +
    `_(Code expires in 15 minutes)_`;

  await sendWhatsAppText(to, text);
}

/**
 * Send a safe error message to the user.
 */
export async function sendErrorMessage(to: string): Promise<void> {
  await sendWhatsAppText(
    to,
    "⚠️ Sorry, I couldn't process that right now. Please try again in a moment."
  );
}

/**
 * Split long text into chunks that fit WhatsApp message limits.
 */
function splitIntoChunks(text: string, maxLength: number): string[] {
  if (text.length <= maxLength) return [text];

  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 0) {
    if (remaining.length <= maxLength) {
      chunks.push(remaining);
      break;
    }
    // Try to split at a sentence boundary
    let splitAt = maxLength;
    const lastPeriod = remaining.lastIndexOf(". ", maxLength);
    const lastNewline = remaining.lastIndexOf("\n", maxLength);
    const boundary = Math.max(lastPeriod, lastNewline);
    if (boundary > maxLength * 0.5) {
      splitAt = boundary + 1;
    }
    chunks.push(remaining.slice(0, splitAt).trim());
    remaining = remaining.slice(splitAt).trim();
  }
  return chunks;
}
