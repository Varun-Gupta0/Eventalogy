# PHASE 25 — FULL EVENTOLOGY PRODUCTION E2E VALIDATION PLAN

## Overview
This document outlines the systematic, end-to-end (E2E) production validation plan for the **Eventology** platform. The goal is to verify the entire system surface—from user onboarding, catalog discovery, AI event planning, approval, relational database propagation, vendor/admin operations, to WhatsApp integration—ensuring zero reliance on mocks, bypasses, or broken state logic.

---

## Validation Stages & Test Coverage

### Stage 25A: Environment & System Readiness
- **Config Audit**: Verify Flutter `firebase_options.dart` / environment settings, Node.js backend `.env` variables (Firestore DB ID `user-data`, PORT 3000, LangGraph parameters, WhatsApp tokens).
- **Service Verification**: Check local runtime availability (Flutter Web on port 8080, Backend on port 3000 via `/health`).
- **Firestore Collections & Schema Audit**: Verify `users`, `vendors`, `venues`, `events`, `enquiries`, `bookings`, `allocations`, `whatsapp_identities`, `whatsapp_processed_messages`, `audit_logs`.
- **Seed Data Verification**: Confirm existence of real vendor, venue, and admin records.

### Stage 25B: Authentication & Authorization
- **Auth Flows**: Login/signup for User, Vendor, Admin roles using Firebase Auth tokens.
- **Role Routing**: Verify GoRouter redirection logic based on user role (`/user/...`, `/vendor/...`, `/admin/...`).
- **Security Boundaries**: Test unauthenticated access attempts to protected routes (`/admin/dashboard`, `/vendor/dashboard`, `/user/events`).
- **Token Integrity**: Test expired/invalid JWT bearer token rejection in backend endpoints (`/api/admin/...`, `/api/agent/...`).

### Stage 25C: User Discovery (Catalog)
- **Home & Search**: Test Home screen banner & categories.
- **Venue & Vendor Listings**: Verify fetching from Cloud Firestore (`venues` & `vendors` collections).
- **Detail Views**: Test `VenueDetailScreen` & `VendorDetailScreen` with valid IDs and non-existent IDs.
- **Data Resilience**: Verify handling of missing optional fields (images, description, ratings).

### Stage 25D: AI Event Architect (LangGraph Integration)
- **Multi-turn Conversation**: Test initial prompt -> AI budget & recommendation generation -> state persistence in `_agent_checkpoints`.
- **Catalog Grounding**: Verify AI suggestions query real Firestore venue/vendor data.
- **Thinking State & Double-Submit Protection**: Ensure UI disables repeat send while waiting for `/api/agent/chat`.
- **Error Recovery**: Test behavior when OpenAI/Gemini API fails or returns malformed structured output.

### Stage 25E: Plan Review & Approval
- **Plan Review UI**: Load `PlanReviewScreen` with draft plan state from LangGraph checkpoint.
- **Interactive Revision**: Modify guest count/budget -> trigger revision turn -> verify updated plan.
- **Approval Flow**: Trigger `Approve & Book` -> call `/api/agent/approve` -> resume LangGraph interrupt.

### Stage 25F: Relational Data Integrity
- **Cascading Records**: Verify single approval generates:
  - `Event` document (`eventId`)
  - `Enquiry` documents (`enquiryId`, matching `eventId`, `userId`, `vendorId`)
  - `Booking` documents (`bookingId`, matching `eventId`, `userId`, `vendorId`)
  - `Allocation` documents (`allocationId`, matching `eventId`, `serviceId`)
- **Foreign Key Consistency**: Confirm zero orphaned downstream records or broken `eventId` associations.

### Stage 25G: Vendor Workflow
- **Vendor Dashboard**: Login as specific vendor -> verify real-time query of incoming `enquiries`, `allocations`, and `bookings`.
- **Status Transitions**: Test accepting/rejecting enquiries and confirming bookings.
- **Vendor Isolation**: Verify Vendor A cannot read/write Vendor B's bookings or allocations.

### Stage 25H: User Event Lifecycle
- **My Events**: Verify `MyEventsScreen` fetches created events for the logged-in user.
- **Event Details**: Verify budget breakdowns, assigned allocations, vendor status indicators, and payment placeholders.

### Stage 25I: Admin Operations
- **Admin Control Center**: Access `/admin` route with Admin claim.
- **Vendor Verification**: Verify approving/suspending vendors updates Firestore state and writes to `audit_logs`.
- **Event Management**: Test admin event cancellation and cascading allocation updates.
- **Authorization Enforcement**: Confirm non-admin users receive HTTP 403 / security rule denial.

### Stage 25J: WhatsApp Multi-Channel Entry Point
- **Webhook Handshake**: GET `/api/whatsapp/webhook` verification with `WHATSAPP_VERIFY_TOKEN`.
- **HMAC Signature Check**: POST `/api/whatsapp/webhook` signature validation using `x-hub-signature-256`.
- **Message Deduplication**: Verify repeat message IDs (`whatsapp_processed_messages`) are ignored.
- **Phone Linking**: Test `/api/whatsapp/initiate-link` & `/api/whatsapp/link` token creation and mapping in `whatsapp_identities`.
- **Agent Bridge Execution**: Verify incoming text routes to `LangGraphAgentBridge` and sends reply via Meta Cloud API.

### Stage 25K: Security Audit
- **Firestore Security Rules**: Audit direct client read/write permissions for all collections.
- **API Guarding**: Verify authorization headers and token extraction across Express routes.
- **Payload Validation**: Test injection/malformed JSON in `/api/agent/chat` and `/api/whatsapp/webhook`.

### Stage 25L: Failure & Recovery
- **Backend Disconnection**: Test UI behavior when backend server is down.
- **Firestore Timeouts**: Verify graceful degradation during network disruption.
- **Invalid Auth Session**: Verify auto-redirect to login when session expires.

---

## Automated Command Verification Suite
1. `dart analyze` (Flutter)
2. `flutter test` (Flutter unit/widget tests)
3. `npm run typecheck` (Backend TS check)
4. `npm run build` (Backend build)
5. `npx jest src/tests/` (Backend test suite including `whatsapp.test.ts`)

---

## Target Output
The completion of this plan will result in **`phase25_e2e_validation_report.md`**, containing the execution results, evidence, and production readiness matrix.
