# EVENTOLOGY — PHASE 24 WHATSAPP IMPLEMENTATION REPORT

## Summary

WhatsApp has been integrated as an external conversational entry point into the existing Eventology AI system. It does NOT create a second AI architecture — it bridges the existing LangGraph orchestration.

---

## Files Created / Modified

### New Backend Files
| File | Purpose |
|------|---------|
| `src/api/whatsapp_routes.ts` | Webhook endpoints (GET verify, POST messages, POST link, POST initiate-link) |
| `src/services/whatsapp_identity_service.ts` | Phone→userId mapping, account linking, deduplication |
| `src/services/whatsapp_messaging_service.ts` | Meta Cloud API client (text, interactive buttons, linking prompts) |
| `src/services/whatsapp_agent_bridge.ts` | Server-side LangGraph invocation with trusted userId |
| `src/tests/whatsapp.test.ts` | 16 unit tests covering identity, webhook parsing, HMAC |

### Modified Backend Files
| File | Change |
|------|--------|
| `src/index.ts` | Mounted `/api/whatsapp` routes; added raw body capture middleware before `express.json()` |

### New Flutter Files
| File | Purpose |
|------|---------|
| `lib/features/user/whatsapp/whatsapp_link_screen.dart` | Account linking UI screen |

### Modified Flutter Files
| File | Change |
|------|--------|
| `lib/core/routing/app_router.dart` | Added `/link-whatsapp` route |

### Modified Firestore Rules
| File | Change |
|------|--------|
| `firestore.rules` | Added `whatsapp_identities` and `whatsapp_processed_messages` rules — backend-only writes |

---

## Architecture

```
WhatsApp User
      ↓
Meta WhatsApp Cloud API
      ↓
POST /api/whatsapp/webhook
      ↓
HMAC-SHA256 Signature Validation
      ↓
Message Deduplication (whatsapp_processed_messages)
      ↓
Per-waId Rate Limiting (20 msg/min)
      ↓
Phone Identity Resolution (whatsapp_identities/{waId})
      ↓ (if unlinked)
Linking Prompt → User opens /link-whatsapp on Flutter Web
      ↓ (if linked)
LangGraph Bridge (whatsapp_agent_bridge.ts)
      ↓
Existing eventologyAgentApp.invoke()
      ↓
AI Response Text Extraction
      ↓ (if pending approval)
Interactive Buttons (Approve/Change)
      ↓
Meta Messaging API → WhatsApp User
```

---

## Security Implemented

| Control | Implementation |
|---------|---------------|
| Webhook spoofing | HMAC-SHA256 `X-Hub-Signature-256` validation via `crypto.timingSafeEqual` |
| Replay attacks | Message ID deduplication via Firestore `whatsapp_processed_messages` |
| Phone trust | `waId` is NEVER used as auth — only as a lookup key in `whatsapp_identities` |
| Credential exposure | All secrets via env vars — none in Flutter, none in WhatsApp messages |
| User isolation | LangGraph state always bound to resolved Firebase `userId` |
| Linking tokens | 32-byte crypto random (64-char hex), single-use, 15-minute TTL |
| Rate limiting | In-memory per-waId 20 msg/min window |
| Firestore rules | `whatsapp_identities` — admin read, no client write; `whatsapp_processed_messages` — no client access |
| No chain-of-thought exposure | Only safe operational state surfaces to WhatsApp users |

---

## Environment Variables Required

```env
# WhatsApp Cloud API (Meta Business Manager)
WHATSAPP_VERIFY_TOKEN=<any random string you choose — set in Meta dashboard too>
WHATSAPP_ACCESS_TOKEN=<permanent access token from Meta App>
WHATSAPP_PHONE_NUMBER_ID=<from Meta Business Dashboard>
WHATSAPP_APP_SECRET=<Meta App Secret — used for HMAC validation>

# Optional — used in linking prompts
EVENTOLOGY_WEB_URL=https://your-eventology-app.com
```

---

## Meta Dashboard Configuration Steps

1. **Create a Meta App** at https://developers.facebook.com/apps/
2. Add the **WhatsApp** product to your app
3. Under WhatsApp > API Setup: note your **Phone Number ID** and **Temporary Access Token** (or generate a permanent one)
4. Under App Settings > Basic: note your **App Secret**
5. Under WhatsApp > Configuration > Webhooks:
   - **Callback URL**: `https://<your-domain>/api/whatsapp/webhook`
   - **Verify Token**: the value you set in `WHATSAPP_VERIFY_TOKEN`
   - Subscribe to: `messages`
6. For local dev, use **ngrok**: `ngrok http 3000` → use the HTTPS URL as callback

---

## Local Development / Testing

```bash
# 1. Start ngrok
ngrok http 3000

# 2. Set env vars in eventology_backend/.env
WHATSAPP_VERIFY_TOKEN=my-local-verify-token
WHATSAPP_ACCESS_TOKEN=<from Meta>
WHATSAPP_PHONE_NUMBER_ID=<from Meta>
WHATSAPP_APP_SECRET=<from Meta>
EVENTOLOGY_WEB_URL=http://localhost:3001

# 3. Configure Meta webhook with ngrok URL
# 4. Start backend
npm run dev

# 5. Run WhatsApp tests
npx jest src/tests/whatsapp.test.ts
```

---

## Test Results

```
PASS src/tests/whatsapp.test.ts (6.57s)

WhatsApp Identity Service — Pure Functions
  normalizeWaId
    ✓ strips leading + sign
    ✓ strips spaces
    ✓ leaves clean digits unchanged
    ✓ strips hyphens
  formatPhoneDisplay
    ✓ prepends +
  generateLinkingToken
    ✓ generates 64-char hex string
    ✓ generates unique tokens

WhatsApp Webhook Payload Structure
  ✓ payload has expected structure
  ✓ can extract message text
  ✓ recognizes interactive button_reply
  ✓ approval command detection — APPROVE
  ✓ approval command detection — button_reply id
  ✓ CHANGE command detection

HMAC Signature Validation
  ✓ valid signature passes
  ✓ invalid signature fails
  ✓ signature has sha256= prefix

Tests: 16 passed, 16 total
```

**Backend typecheck**: PASS  
**Backend build**: PASS  
**Dart analyze**: 0 errors (153 pre-existing style warnings — unchanged from prior phases)

---

## Approval Flow on WhatsApp

When the AI generates an event plan and the LangGraph graph enters the approval interrupt:

1. Backend detects `hasPendingApproval = true`
2. Sends WhatsApp interactive message with two buttons:
   - **✅ Approve Plan**
   - **✏️ Change Something**
3. User taps button (or types `APPROVE` / `CHANGE`)
4. Backend calls `submitApprovalForWhatsApp()` which invokes `Command({ resume: ... })`
5. The SAME approval flow as Flutter web runs — creates Event, Bookings, Enquiries, Allocations

---

## Known Limitations

1. **Rate limiting**: In-memory per-waId limiting — resets on server restart. Production should use Redis.
2. **Account linking UX**: User must visit the Flutter web app to link their account. A future enhancement could use WhatsApp OTP-style flows via the Meta Business API.
3. **Media**: Only text and interactive buttons supported. Images, PDFs, location not handled (user prompted to send text).
4. **Vendor notifications**: Not implemented in this phase. Architecture note: when a booking is confirmed, `communication_agent.ts` can be extended to call `sendWhatsAppText()` if the vendor's linked `waId` is known.
5. **Production rate limiting**: Upgrade to Redis-backed rate limiter before production launch.
6. **Phone normalization at user creation**: `UserModel.phone` field is not normalized. Future: normalize at write time for reverse lookup.

---

## Future: Vendor WhatsApp Notification Architecture

To extend WhatsApp to vendor notifications (Phase 25+):

1. Add `waId` field to `VendorModel`
2. Extend `whatsapp_identities` with `role: "vendor"`
3. When `communication_agent.ts` dispatches vendor notifications, call `sendWhatsAppText(vendor.waId, ...)`
4. Existing deduplication and rate limiting applies
5. No changes needed to the identity service — same collections, same security model

---

## Production Deployment Checklist

- [ ] Configure production Meta App with production webhook URL
- [ ] Set all 4 env vars in production environment
- [ ] Deploy backend (ensure port 3000 or configured PORT is accessible)
- [ ] Verify webhook in Meta dashboard (GET verification)
- [ ] Send test WhatsApp message — confirm identity record created in Firestore
- [ ] Complete account linking flow — confirm `whatsapp_identities` document updated to `linked`
- [ ] Send "I want to plan a birthday party" — confirm LangGraph invoked
- [ ] Verify AI response received on WhatsApp
- [ ] Test multi-turn conversation (guests, location, date)
- [ ] Test approval flow — tap Approve — verify Event + Booking in Firestore
- [ ] Upgrade in-memory rate limiter to Redis for production scale
