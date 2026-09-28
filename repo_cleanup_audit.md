# Repository Cleanup Audit Report

## 1. SAFE TO DELETE
The following files are verified to be completely unused, obsolete prototypes, or one-time data manipulation scripts. **Deleting these will not impact production functionality.**

**Orphaned Singular Models (Unused by UI):**
*The Admin Dashboard and system functionality were built using pluralized models for transaction and system data. These singular models are dead code.*
- `lib/models/agent_log_model.dart`
- `lib/models/agent_task_model.dart`
- `lib/models/ai_plan_model.dart`
- `lib/models/ai_recommendation_model.dart`
- `lib/models/allocation_model.dart`
- `lib/models/audit_log_model.dart`
- `lib/models/booking_model.dart`
- `lib/models/enquiry_model.dart`
- `lib/models/event_model.dart`
- `lib/models/notification_model.dart`
- `lib/models/payment_model.dart`
- `lib/models/review_model.dart`
- `lib/models/setting_model.dart`

**Orphaned Repositories (Unused by UI):**
- `lib/services/firestore/enquiry_repository.dart`
- `lib/services/firestore/event_repository.dart`
- `lib/services/firestore/transaction_repositories.dart` (Replaced by individual plural repositories like `bookings_repository.dart`).

**One-Time Backend Scripts (Data Hazards):**
*These scripts were used for initial setup/migration. Keeping them risks accidental execution that could corrupt production data.*
- `eventology_backend/src/scripts/seedInitialServices.ts`
- `eventology_backend/src/scripts/seedCategories.ts`
- `eventology_backend/src/scripts/readCategories.ts`
- `eventology_backend/src/scripts/getLegacyServices.ts`
- `eventology_backend/src/scripts/deleteLegacyServices.ts`

**Abandoned Node.js AI Prototype:**
*The target architecture uses a LangGraph-based AI runtime. The current Node.js Express server is a basic LLM passthrough prototype and is obsolete.*
- `eventology_backend/src/server.ts`
- `eventology_backend/src/openRouterService.ts`
- `eventology_backend/src/aiProvider.ts`

## 2. KEEP
All production application code handling the UI, Authentication, and Firestore ERP architecture must remain.

**Actively Used Repositories & Models (Pluralized):**
- Transactions & AI Data: `events_`, `enquiries_`, `bookings_`, `allocations_`, `payments_`, `reviews_`, `notifications_`, `audit_logs_`, `settings_`, `ai_plans_`, `ai_recommendations_`, `agent_tasks_`, `agent_logs_` (Both model and repository files).

**Actively Used Repositories & Models (Singular - Master Data):**
- `vendor_`, `venue_`, `location_`, `package_`, `service_`, `user_`, `category_`, `event_type_`, `venue_type_` (Both model and repository files).

## 3. KEEP FOR NOW
- `eventology_backend/src/scripts/setRole.ts`: Setting custom claims (`admin`) is required for new developer onboarding. Until this is migrated to a secure Cloud Function, this script remains useful.

## 4. POSSIBLY OBSOLETE — REQUIRES REVIEW
- **Verification Scripts** (`eventology_backend/src/scripts/verify*.ts` and `verifyAll.ps1`):
  There are 22 verification scripts validating Firestore collections. While read-only and safe, maintaining standalone TypeScript scripts to validate schema (which is already enforced by the Dart models in the app) is redundant. We should decide whether to integrate them into a CI/CD pipeline or delete them.

## 5. PRODUCTION-CRITICAL FILES
- `firestore.rules`: Essential for securing the entire ERP and AI Control Plane.
- `lib/services/firestore/master_data_repository.dart`: Contains critical initial seeding logic for Categories, Event Types, and Venue Types triggered via the Admin Dashboard.
- `lib/core/firebase/firestore_config.dart`: Core entry point.

## 6. CURRENT AI/AGENT ARCHITECTURE
The current architecture consists of a simple Node.js Express server (`server.ts`) that exposes an `/api/ai/generate-event-plan` endpoint. It uses `openRouterService.ts` to forward a static prompt (`aiProvider.ts`) to OpenRouter and returns JSON directly to the Flutter UI. 
**It does not utilize LangGraph, does not persist data to Firestore, and does not execute workflows.** It is safe to completely replace this Node.js backend with the intended LangGraph API.

## 7. RECOMMENDED CLEANUP ORDER
1. **Remove Duplicate Dart Code:** Delete all unused singular models and the orphaned `transaction_repositories.dart` to clarify the active schema.
2. **Remove Dangerous Scripts:** Delete the data migration/seeding scripts from the backend.
3. **Deprecate Node.js Backend:** Tear down the Express server/OpenRouter prototype in preparation for the LangGraph API scaffolding.
4. **Review Verification Scripts:** Decide the fate of the `verify*.ts` suite.
