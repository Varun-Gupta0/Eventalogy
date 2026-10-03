# EVENTOLOGY — PHASE 24A: WHATSAPP ARCHITECTURE AUDIT

## 1. Current Architecture Summary

### Backend
- **Runtime**: Node.js + TypeScript on Express 5
- **Entry**: `src/index.ts` — mounts `/api/agent` and `/api/admin`
- **Auth Middleware**: `src/middleware/auth.ts` — `verifyFirebaseToken()` validates Firebase ID Token from `Authorization: Bearer <token>` header
- **AI Runtime**: LangGraph `eventologyAgentApp` compiled in `src/graph/index.ts`
- **State**: `src/graph/state.ts` — `GraphState` annotation with full lifecycle fields
- **Checkpointer**: Custom `FirestoreCheckpointer` in `src/services/firestore_checkpointer.ts` — persists to Firestore `_agent_checkpoints/{thread_id}/checkpoints/{checkpoint_id}`
- **Firebase**: Uses named Firestore database `user-data` (not default)

### Frontend
- **Flutter Web** — Firebase Auth + GoRouter
- **AgentChatService** — HTTP client calling `/api/agent/chat` and `/api/agent/approve` with Firebase ID Token

### Conversation State Findings
- **A. Where it lives**: Firestore `_agent_checkpoints` collection via custom `FirestoreCheckpointer`
- **B. conversationId**: UUID v4, generated on first message; used as `configurable.thread_id`
- **C. Firebase UID association**: `userId` stored inside LangGraph state at first message
- **D. Persistence**: YES — state fully persisted across restarts; resumable from any channel
- **E. Auth requirement**: `/api/agent/chat` requires Firebase ID Token — WhatsApp webhook cannot produce one. Backend must act as trusted intermediary.
- **F. LangGraph resume**: Re-invoke with same `conversationId` as `thread_id`
- **G. External channel reuse**: Feasible — backend invokes `eventologyAgentApp.invoke()` directly with trusted `userId`
- **H. Phone in UserModel**: `phone` field EXISTS as nullable `String?` — not indexed, not normalized
- **I. Phone normalization**: None currently
- **J. Notification layer**: None exists

---

## 2. Required WhatsApp Components

| Component | Purpose |
|-----------|---------|
| `GET/POST /api/whatsapp/webhook` | Receive Meta Cloud API events |
| HMAC Signature Validator | Verify `X-Hub-Signature-256` |
| Message Deduplicator | Idempotency via message ID |
| WhatsApp Identity Service | `whatsapp_identities/{waId}` — phone to userId mapping |
| Account Linking Flow | Secure token-based linking |
| Conversation Resolver | waId to conversationId mapping |
| LangGraph Bridge | Invoke agent server-side with trusted userId |
| Response Adapter | Format AI text to WhatsApp constraints |
| Meta Messaging API Client | Send messages via REST |
| Rate Limiter | Protect against floods |

---

## 3. Identity Mapping Design

WhatsApp provides only a `wa_id` (phone number). This is NEVER trusted as auth by itself.

### Firestore: `whatsapp_identities/{waId}`
```json
{
  "waId": "919876543210",
  "phoneNumber": "+91 98765 43210",
  "userId": "firebase_uid_or_null",
  "status": "unlinked|linked|blocked",
  "conversationId": "uuid_or_null",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "lastMessageAt": "Timestamp",
  "linkingToken": "hex_or_null",
  "linkingTokenExpiresAt": "Timestamp_or_null"
}
```

### Linking Flow
1. Unlinked user sends WhatsApp message
2. Backend creates identity record (`status: unlinked`)
3. Backend responds with: "Link your account at [URL]. Code: XXXXXX (expires 15 min)"
4. User authenticates on web, submits code at `POST /api/whatsapp/link`
5. Backend validates token (single-use, 15-min TTL, crypto-random)
6. Backend sets `userId = firebase_uid`, `status = linked`
7. Future messages processed as that Firebase user

---

## 4. Conversation Mapping Decision

**Option B chosen**: Separate WhatsApp conversation IDs. Each channel maintains its own `conversationId`. Same Firestore business data (Events, Bookings) is visible on web.

```
User (Firebase UID)
  ├── Web Conversations (_agent_checkpoints)
  ├── WhatsApp Conversations (conversationId in whatsapp_identities)
  ├── Events (shared — visible everywhere)
  └── WhatsApp Identity (whatsapp_identities/{waId})
```

---

## 5. Security Model

| Concern | Mitigation |
|---------|-----------|
| Webhook spoofing | HMAC-SHA256 on every POST |
| Replay attacks | messageId deduplication in Firestore |
| Phone trust | Never auth; only lookup key |
| Credential exposure | All secrets in env vars only |
| User isolation | State bound to resolved userId |
| Token security | 32-byte crypto random, single-use, 15-min TTL |
| Rate limiting | Per-waId limits |

---

## 6. Firestore Schema Additions

### `whatsapp_identities/{waId}` — backend-only writes
### `whatsapp_processed_messages/{messageId}` — deduplication TTL-based

---

## 7. Environment Variables Required

```
WHATSAPP_VERIFY_TOKEN=<random string you choose for webhook verification>
WHATSAPP_ACCESS_TOKEN=<Meta permanent access token>
WHATSAPP_PHONE_NUMBER_ID=<from Meta Business Dashboard>
WHATSAPP_APP_SECRET=<Meta App Secret for HMAC validation>
```

---

## 8. Message Lifecycle (POST webhook)

1. Validate HMAC signature
2. Parse — extract message fields
3. Deduplicate via messageId
4. Resolve/create `whatsapp_identities` record
5. If `unlinked` → send linking instructions → return 200
6. If `blocked` → silent ignore → return 200
7. Resolve conversationId (create if none)
8. Invoke LangGraph directly with trusted `userId`
9. Extract AI response text
10. Send to user via Meta REST API
11. Update `lastMessageAt`
12. Return 200 to Meta (always)

---

## 9. Failure Handling

| Failure | User Response | Internal |
|---------|--------------|---------|
| Invalid signature | 403 | Log + alert |
| Duplicate message | 200 (skip) | Log |
| Unlinked user | Linking instructions | Create record |
| LangGraph failure | "Sorry, try again." | Log + retry 1x |
| WhatsApp API fail | No delivery | Log + retry |
| Unsupported type | "Please send text." | Log |

---

## 10. Implementation Assumptions

- Meta WhatsApp Cloud API (official — not unofficial automation)
- WhatsApp Business number pre-registered in Meta Business Manager
- `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_APP_SECRET` available as env vars
- Webhook URL publicly accessible (ngrok for dev)
- `user-data` named Firestore database used for all new collections
- Account linking via Flutter web app (not WhatsApp itself)
- Text-only messages for MVP
- One active WhatsApp conversation thread per identity
- Existing `/api/agent/chat` NOT modified — WhatsApp bridge calls LangGraph directly
