# EVENTOLOGY PHASE 8 — AI READINESS AUDIT

## 1. Current Architecture & Lifecycle Trace
The AI Control Plane exists as a data layer in Firestore and is accessible via the Flutter Admin Dashboard.
**Target Lifecycle:**
EVENT → AI PLAN → AI RECOMMENDATION → AGENT TASK → APPROVAL → AGENT EXECUTION → AGENT LOG

**Current Reality:**
- **Source Files:** Models/Repositories exist in `lib/models/` and `lib/services/firestore/`. Admin UIs in `lib/features/admin/`.
- **Firestore Collections:** `ai_plans`, `ai_recommendations`, `agent_tasks`, `agent_logs`.
- **Executable:** **NO**. The entire Control Plane is currently a **UI and Data layer only**. No automated agents or triggers are hooked into these collections.
- **Approval Flow:** The UI allows Admins to click "Approve" on an `agent_tasks` document, which successfully updates the Firestore document status to `approved`, but nothing listens to or acts upon this change.

---

## 2. AI PLANS
- **Can it be created?** Yes, via Firestore SDK.
- **Who can create it?** Authenticated users (if `userId == request.auth.uid`) or Admins.
- **Can it be updated?** Only by Admins.
- **Association:** Through the `eventId` and `userId` fields on the document.
- **Actual AI Generation?** **NO**. While an OpenRouter backend exists, it only returns transient JSON to the client (via `ai_planner_service.dart`). It does not persist an `AiPlanModel` to Firestore.
- **State:** It is currently purely a CRUD data layer.

---

## 3. AI RECOMMENDATIONS
- **Validation:** There is **NO** backend or Firestore rule validation enforcing the validity of `eventId`, `serviceId`, `vendorId`, `venueId`, or `score`. Integrity relies entirely on the client SDK.
- **AI-Generated?** **NO**. They are entirely unhooked from any LLM pipeline at this stage.

---

## 4. AGENT TASKS
- **Approval Enforced Server-Side?** **NO**. There are no Firebase Cloud Functions or backend validators enforcing a state machine.
- **Who can approve/reject?** Admins only (as per `firestore.rules`, ordinary users have no write access).
- **Status Transitions:** Any string is technically allowed. The UI enforces the `approved`/`rejected` string values.
- **Client Manipulation:** Ordinary clients **cannot** change `approvedBy`, `status`, or bypass `requiresApproval` because ordinary clients do not have write access to the `agent_tasks` collection. Admins, however, can rewrite any field at any time.
- **Actual Executor?** **NONE**. There is no worker polling the collection or Cloud Function triggering on `status == 'approved'`.

---

## 5. AGENT LOGS
- **Who can write?** Admins only.
- **Fake logs by clients?** No. Ordinary clients are blocked by `firestore.rules`.
- **Auto-generated?** **NO**. 
- **Validation:** `taskId` is not validated server-side.
- **Append-only?** **NO**. Admins can currently update or delete logs because the rule states: `allow create, update, delete: if isAdmin();`.

---

## 6. OPENROUTER / LLM
An LLM integration **DOES** exist, but it is isolated from the ERP data layer.
- **Location:** `eventology_backend/src/server.ts`, `openRouterService.ts`, `aiProvider.ts`.
- **Configuration:** Uses `.env` for `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` (default: `meta-llama/llama-3.1-8b-instruct:free`).
- **Flow:** 
  1. Frontend sends POST to `/api/ai/generate-event-plan`.
  2. Backend injects `systemInstruction` (JSON format enforcement) and `generatePrompt`.
  3. OpenRouter API is called via `fetch`.
  4. Backend parses JSON `content`.
  5. JSON payload is returned to the client.
- **Missing:** This flow never writes to Firestore.

---

## 7. EVENT → AI TRIGGER
- **Status:** **NO TRIGGER EXISTS.**
- **Trace:** Creating an Event via `events_repository.dart` simply writes a document to the `events` collection. It does not invoke the LLM backend, nor does it spawn an AI Plan or Agent Task.

---

## 8. SECURITY FINDINGS
- **Custom Claims:** Effectively enforced. `isAdmin()` securely relies on the Auth token.
- **Impersonation:** Clients cannot impersonate agents or create fake logs because `agent_tasks` and `agent_logs` require `isAdmin()`.
- **Weaknesses (Admin Level):** 
  - Admins can delete or alter `audit_logs` and `agent_logs`. These should ideally be immutable (create-only).
  - Admins can rewrite completed tasks.
- **Weaknesses (Data Integrity):** No strict schema enforcement (typing, required fields, foreign key checks) exists inside `firestore.rules`. We rely on TS Verification scripts for retroactive auditing.

---

## 9. RECOMMENDED ARCHITECTURE (FIRST REAL AI FEATURE: EVENT PLANNING AGENT)
To build a clean, secure AI loop without exposing the database to the client:

1. **The Request:** Client creates an Event, then calls a secure backend endpoint (e.g., Cloud Function or the existing Express server) requesting a Plan.
2. **The Generation:** Backend queries OpenRouter.
3. **The Data Layer:** 
   - Backend securely creates the `ai_plans` and `ai_recommendations` documents in Firestore.
   - Backend creates an `agent_tasks` document for executing the plan (e.g., booking services). It sets `requiresApproval: true` and `status: pending_approval`.
4. **The Approval:** Admin reviews the plan on the Admin Dashboard and clicks "Approve". This updates the `agent_tasks` document status to `approved`.
5. **The Execution (Cloud Function):** 
   - An `onDocumentUpdated` Firestore trigger listens to `agent_tasks`. 
   - If `status` changes from `pending_approval` to `approved`, the Cloud Function executes the required logic (e.g., calling vendors).
   - The Cloud Function securely writes the outcome to `agent_logs` and updates the task to `completed`.

---

## 10. EXACT NEXT IMPLEMENTATION STEPS
1. **Immutable Logs:** Update `firestore.rules` to remove `update` and `delete` permissions for `agent_logs` and `audit_logs` (even for Admins).
2. **Backend Integration:** Update `openRouterService.ts` to utilize the Firebase Admin SDK to write the generated response directly into the `ai_plans` and `ai_recommendations` collections.
3. **Task Generation:** Modify the backend to generate a corresponding `agent_tasks` document upon plan creation.
4. **Executor Trigger:** Create a Firebase Cloud Function that listens for updates to `agent_tasks` to act on approved requests.
