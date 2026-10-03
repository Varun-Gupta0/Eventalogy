import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import crypto from "crypto";

const COLLECTION = "whatsapp_identities";
const DEDUP_COLLECTION = "whatsapp_processed_messages";

export type WhatsAppIdentityStatus = "unlinked" | "linked" | "blocked";

export interface WhatsAppIdentity {
  waId: string;
  phoneNumber: string;
  userId: string | null;
  status: WhatsAppIdentityStatus;
  conversationId: string | null;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  lastMessageAt: FirebaseFirestore.Timestamp;
  linkingToken: string | null;
  linkingTokenExpiresAt: FirebaseFirestore.Timestamp | null;
}

/**
 * Normalize a WhatsApp wa_id (E.164 digits only, no '+').
 * Meta sends e.g. "919876543210" which is already clean, but defensively strip any non-digits.
 */
export function normalizeWaId(waId: string): string {
  return waId.replace(/\D/g, "");
}

/**
 * Format E.164 digits to a human-readable display string.
 * e.g. "919876543210" → "+91 98765 43210"
 */
export function formatPhoneDisplay(waId: string): string {
  return `+${waId}`;
}

/**
 * Resolve or create a WhatsApp identity document.
 * If the waId is seen for the first time, creates an "unlinked" record.
 */
export async function resolveOrCreateIdentity(waId: string): Promise<WhatsAppIdentity> {
  const normalized = normalizeWaId(waId);
  const ref = db.collection(COLLECTION).doc(normalized);
  const snap = await ref.get();

  if (snap.exists) {
    return snap.data() as WhatsAppIdentity;
  }

  // First-time seen — create unlinked record
  const now = FieldValue.serverTimestamp() as any;
  const identity: Omit<WhatsAppIdentity, "createdAt" | "updatedAt" | "lastMessageAt"> & {
    createdAt: any; updatedAt: any; lastMessageAt: any;
  } = {
    waId: normalized,
    phoneNumber: formatPhoneDisplay(normalized),
    userId: null,
    status: "unlinked",
    conversationId: null,
    createdAt: now,
    updatedAt: now,
    lastMessageAt: now,
    linkingToken: null,
    linkingTokenExpiresAt: null,
  };

  await ref.set(identity);
  const fresh = await ref.get();
  return fresh.data() as WhatsAppIdentity;
}

/**
 * Update lastMessageAt on an identity record.
 */
export async function touchIdentity(waId: string): Promise<void> {
  const normalized = normalizeWaId(waId);
  await db.collection(COLLECTION).doc(normalized).update({
    lastMessageAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Update conversationId on an identity record.
 */
export async function setIdentityConversation(waId: string, conversationId: string): Promise<void> {
  const normalized = normalizeWaId(waId);
  await db.collection(COLLECTION).doc(normalized).update({
    conversationId,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Generate a cryptographically random linking token.
 * Returns a hex string of 32 bytes (64 hex chars).
 */
export function generateLinkingToken(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Issue a linking token for an unlinked identity.
 * Overwrites any existing token. Token expires in 15 minutes.
 */
export async function issueLinkingToken(waId: string): Promise<string> {
  const normalized = normalizeWaId(waId);
  const token = generateLinkingToken();
  const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

  await db.collection(COLLECTION).doc(normalized).update({
    linkingToken: token,
    linkingTokenExpiresAt: expiresAt,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return token;
}

/**
 * Link a WhatsApp identity to a Firebase UID.
 * Validates the linking token (single-use, not expired).
 * Returns the waId if successful, null if the token is invalid.
 */
export async function linkIdentityToUser(
  token: string,
  userId: string
): Promise<{ waId: string; success: boolean; error?: string }> {
  // Find identity by token
  const snap = await db
    .collection(COLLECTION)
    .where("linkingToken", "==", token)
    .limit(1)
    .get();

  if (snap.empty) {
    return { waId: "", success: false, error: "Invalid or already-used linking code." };
  }

  const doc = snap.docs[0];
  const identity = doc.data() as WhatsAppIdentity;

  // Check expiry
  const expiresAt = identity.linkingTokenExpiresAt?.toMillis() ?? 0;
  if (Date.now() > expiresAt) {
    // Clear the expired token
    await doc.ref.update({
      linkingToken: null,
      linkingTokenExpiresAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { waId: identity.waId, success: false, error: "Linking code has expired. Please try again." };
  }

  // Check not already linked to a different user
  if (identity.userId && identity.userId !== userId) {
    return { waId: identity.waId, success: false, error: "This WhatsApp number is already linked to a different account." };
  }

  // Link the identity — clear token (single-use)
  await doc.ref.update({
    userId,
    status: "linked",
    linkingToken: null,
    linkingTokenExpiresAt: null,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { waId: identity.waId, success: true };
}

/**
 * Check whether a message ID has already been processed.
 * Uses a Firestore TTL-backed collection for deduplication.
 * Returns true if the message is a duplicate (already processed).
 */
export async function isMessageDuplicate(messageId: string): Promise<boolean> {
  const ref = db.collection(DEDUP_COLLECTION).doc(messageId);
  const snap = await ref.get();
  if (snap.exists) return true;

  // Mark as processed; set expireAt for Firestore TTL cleanup (24h)
  await ref.set({
    messageId,
    processedAt: FieldValue.serverTimestamp(),
    expireAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });
  return false;
}
