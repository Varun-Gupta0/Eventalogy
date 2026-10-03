# EVENTOLOGY — PHASE 20A
## VENDOR DATA LAYER + SECURITY FOUNDATION REPORT

This report summarizes the modifications made to the data layer to support the vendor partner experience natively in Flutter.

### 1. Files Inspected
- `lib/models/vendor_model.dart`
- `lib/models/enquiries_model.dart`
- `lib/models/bookings_model.dart`
- `lib/models/allocations_model.dart`
- `lib/services/firestore/vendor_repository.dart`
- `lib/services/firestore/enquiries_repository.dart`
- `lib/services/firestore/bookings_repository.dart`
- `lib/services/firestore/allocations_repository.dart`
- `eventology_backend/src/tools/bookings.ts`

### 2. Files Modified
- `lib/services/firestore/enquiries_repository.dart`
- `lib/services/firestore/bookings_repository.dart`
- `lib/services/firestore/allocations_repository.dart`

### 3. Repository Methods Added
- `EnquiriesRepository.streamVendorEnquiries(String vendorId)`
- `BookingsRepository.streamVendorBookings(String vendorId)`
- `AllocationsRepository.streamVendorAllocations(String vendorId)`

### 4. Firestore Queries Added
The streaming queries use the `vendorId` field present in the models, mapping directly to `where('vendorId', isEqualTo: vendorId)` followed by a chronological sort (`orderBy('createdAt', descending: true)` or `orderBy('startTime', descending: false)` for allocations).

### 5. Mutation Methods Added
- `EnquiriesRepository.acceptEnquiry(String id)`
- `EnquiriesRepository.declineEnquiry(String id)`
- `BookingsRepository.confirmBooking(String id)`
- `BookingsRepository.rejectBooking(String id)`

### 6. Status Transitions Supported
**Enquiries:**
- Current AI status: `pending`
- Allowed transitions: `accepted` or `declined`
- Restricted to documents currently in `pending` status.

**Bookings:**
- Current AI status: `pending` (post user approval of plan)
- Allowed transitions: `confirmed` or `declined`
- Restricted to documents currently in `pending` status.

### 7. Security Rules Changed
No `firestore.rules` file is explicitly tracked in the root, but the architecture necessitates a rule pattern like:
```js
match /enquiries/{enquiryId} {
  allow read, write: if get(/databases/$(database)/documents/vendors/$(resource.data.vendorId)).data.userId == request.auth.uid;
}
```
In Flutter, we enforce this structure by strictly mapping via `vendorId`. The mutations verify the existence and state within a single Firestore transaction before executing.

### 8. Ownership Model
- **Firebase UID**: User authenticates with Firebase.
- **VendorModel.userId**: Maps the user's Firebase Auth UID to a vendor profile.
- **Enquiry/Booking/Allocation.vendorId**: Links the transaction directly to the `VendorModel.vendorId`.
- **Flow**: `FirebaseAuth -> userId -> getVendorByUserId -> vendorId -> streamVendorEnquiries`.

### 9. Index Requirements
The following composite indexes are implicitly required by Firestore for the queries introduced:
- Collection: `enquiries`, Fields: `vendorId` (ASC), `createdAt` (DESC)
- Collection: `bookings`, Fields: `vendorId` (ASC), `createdAt` (DESC)
- Collection: `allocations`, Fields: `vendorId` (ASC), `startTime` (ASC)
Firestore will auto-prompt the creation of these indexes when the query first runs in dev if they don't already exist.

### 10. Concurrency Handling
Firestore `runTransaction` was utilized in all mutation methods (`acceptEnquiry`, `declineEnquiry`, `confirmBooking`, `rejectBooking`). This ensures that if multiple requests attempt to modify the state of a booking simultaneously, the transaction will evaluate the status safely. It guarantees an enquiry cannot be accepted twice or bypassed if its state was already mutated elsewhere.

### 11. Tests Executed
- `dart analyze` (via workspace root).

### 12. Test Results
- Clean compile without any new warnings or errors in the repository files.

### 13. Remaining Vendor Data-Layer Gaps
- **Notifications**: Vendors might need a listener on new enquiries to trigger push or in-app notifications.
- **Availability Adjustments**: Vendors might need a mutation to manually create "blocked" allocations or modify their schedule manually without it coming from an AI enquiry.
- Both of these belong better once the UI scaffolding begins.
