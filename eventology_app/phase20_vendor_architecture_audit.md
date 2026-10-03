# EVENTOLOGY — PHASE 20
## VENDOR PARTNER EXPERIENCE — ARCHITECTURE AUDIT

This report fulfills the requirement to audit the existing Eventology vendor architecture, Firebase backend, and Stitch references before proceeding with the implementation of the Vendor Partner Experience.

### 1. Current Vendor Architecture
Currently, the vendor surface is barely a stub. Users with the `vendor` role are redirected to `/vendor`, which resolves to a single placeholder `VendorDashboardScreen`. 

The data models (`VendorModel`, `BookingModel`, `EnquiryModel`, `AllocationModel`) exist and are robust, correctly storing references to `vendorId`, `userId`, `eventId`, and `serviceId`. The backend creates these records correctly via Langchain tools when the AI Booking Agent orchestrates a plan. 

### 2. Existing Vendor Files
- **UI:** `lib/features/vendor/vendor_dashboard_screen.dart` (Placeholder only)
- **Models:** `lib/models/vendor_model.dart`
- **Repositories:** `lib/services/firestore/vendor_repository.dart`
- **Routing:** A single `/vendor` route in `lib/core/routing/app_router.dart`

### 3. Existing Firestore Models
- **vendors:** Stores vendor details, linked to Firebase Auth UID via `userId`.
- **enquiries:** Represents a user's interest in a vendor's service (created by the AI).
- **bookings:** The confirmed booking record (created by the AI post-approval).
- **allocations:** Time-slot locking for vendors/venues.

### 4. Existing Repositories
The following repositories exist but lack vendor-specific querying logic:
- `VendorRepository`
- `EnquiriesRepository`
- `BookingsRepository`
- `AllocationsRepository`
*Currently, the Enquiries and Bookings repositories only export a generic `stream()` that returns ALL documents.*

### 5. Existing Backend Support
The backend handles the *creation* of transactional state via the AI Agents (`create_enquiry`, `create_booking`, `create_allocation` in `bookings.ts`). 
**There are no dedicated REST APIs for Vendor mutations.**

### 6. Booking / Enquiry Lifecycle
1. **AI Recommendation:** Agent identifies vendor.
2. **Enquiry:** `create_enquiry` creates a record (`status: pending`).
3. **Approval:** User approves the AI Plan.
4. **Booking:** `create_booking` creates a record (`status: pending`, `paymentStatus: unpaid`).
5. **Allocation:** `create_allocation` locks the vendor's schedule.

### 7. Stitch Reference Mapping
Located in `stitch_eventology_india_ui_planning/`:
- `vendor_partner_dashboard_1-6`: Maps to Vendor Dashboard Overview, Enquiries list, Bookings list, and Revenue analytics.
- `artist_&_vendor_profile`: Maps to the Vendor Profile / Portfolio settings screen.
- `vendor_selection`: Relates more to the User's selection UI or a detailed Vendor preview.

### 8. Missing Screens
We need to create a structured UI shell similar to `UserShellScreen`:
- `VendorShellScreen` (Navigation wrapper)
- `VendorDashboardOverviewScreen` (KPIs, active items)
- `VendorEnquiriesScreen` (List of pending enquiries)
- `VendorBookingsScreen` (List of confirmed/pending bookings)
- `VendorProfileScreen` (Manage services and portfolio)

### 9. Missing Data Fields / Queries
- The Models are sufficient, but **Repository queries are missing**. We need methods like:
  - `EnquiriesRepository.streamVendorEnquiries(String vendorId)`
  - `BookingsRepository.streamVendorBookings(String vendorId)`

### 10. Missing Backend Mutations
Vendors need to interact with the transactional state:
- Accept/Decline Enquiry -> Mutates `enquiries` status.
- Confirm Booking -> Mutates `bookings` status.
Since Eventology heavily utilizes Firestore directly from the Flutter client (backed by Security Rules), these mutations can be implemented directly in the Flutter Repositories rather than building new Node.js APIs, keeping infrastructure lean.

### 11. Security Findings
**CRITICAL:** To allow Flutter to query and mutate `enquiries` and `bookings` securely, Firestore Security Rules must be strictly enforced.
- A vendor user (`request.auth.uid`) must only be allowed to read/write an enquiry if the `vendorId` on the enquiry resolves to a vendor document owned by that `request.auth.uid`.
- Example rule logic needed: `get(/databases/$(database)/documents/vendors/$(resource.data.vendorId)).data.userId == request.auth.uid`
- Currently, if a user hits the generic `stream()` in the repositories, they could potentially read all data if rules are missing or too permissive.

### 12. Routing Gaps
- `app_router.dart` only maps `/vendor`. It needs a `StatefulShellRoute` for the Vendor experience, with branches for Dashboard, Enquiries, Bookings, and Profile.

### 13. Mock-Data Findings
- The current vendor dashboard is a blank placeholder. There is no mock data to eliminate in the UI, but we must ensure we strictly bind to Firestore streams when building the new screens.

### 14. Recommended Implementation Order
1. **Data Layer Update:** Add `streamVendorEnquiries` and `streamVendorBookings` to the respective repositories. Add mutation methods (e.g. `updateStatus`).
2. **Routing & Shell:** Create `VendorShellScreen` and update `app_router.dart` with a `StatefulShellRoute`.
3. **Dashboard Overview:** Implement `VendorDashboardView` matching `vendor_partner_dashboard_1`.
4. **Enquiries & Bookings:** Implement the list and detail views for transactional states.
5. **Security Rules:** Ensure `firestore.rules` (if accessible) protects these queries.

### 15. Exact Files to Create
- `lib/features/vendor/shell/vendor_shell_screen.dart`
- `lib/features/vendor/dashboard/vendor_dashboard_view.dart`
- `lib/features/vendor/enquiries/vendor_enquiries_view.dart`
- `lib/features/vendor/bookings/vendor_bookings_view.dart`
- `lib/features/vendor/profile/vendor_profile_view.dart`

### 16. Exact Files to Modify
- `lib/core/routing/app_router.dart`
- `lib/services/firestore/enquiries_repository.dart`
- `lib/services/firestore/bookings_repository.dart`

### 17. Files that should NOT be touched
- `eventology_backend/src/tools/bookings.ts` (AI Booking flow)
- `eventology_backend/src/tools/vendors.ts`
- Any of the User AI Chat or Plan Review screens. The AI runtime layer remains the source of truth for generating these records.

### 18. Risks
- Creating overlapping data states: We must consume the *exact* output of the AI Booking Agent, not recreate it.
- Security bypass if repository streams are not properly filtered by `vendorId`.

### 19. Acceptance Criteria
- A user with the `vendor` role logs in and sees a premium dashboard.
- The dashboard streams real `enquiries` and `bookings` tied specifically to their `vendorId`.
- The vendor can change the status of an enquiry from 'pending' to 'accepted'/'declined'.
- No changes to the AI Chat runtime or architecture were required.
