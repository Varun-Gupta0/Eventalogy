# PHASE 26 — AUTH ROLE AUDIT REPORT

## Date: 2026-10-02
## Status: READ-ONLY AUDIT COMPLETE

---

## 1. Current Authentication Flow

```
Firebase Auth (email + password)
    ↓
AuthStateNotifier (singleton, listens to idTokenChanges())
    ↓
user.getIdTokenResult() → reads Firebase Custom Claims
    ↓
idTokenResult.claims['role'] → 'admin' | 'vendor' | 'user'
    ↓
Fallback: 'user' (for new signups before claims are set)
    ↓
GoRouter redirect evaluates role → routes to /home, /vendor, or /admin
```

**Source:** `lib/services/auth_state_notifier.dart`

---

## 2. Current Signup Flow

```
SignupScreen (email, password, name only — NO role selector)
    ↓
FirebaseAuthService.signUp(email, password, name)
    ↓
Firebase Auth creates UID
    ↓
Firestore: users/{uid} set with role: 'user' (hardcoded)
    ↓
GoRouter redirect triggers after auth state changes
    ↓
AuthStateNotifier checks claims → no claim set yet → fallback 'user'
    ↓
User routed to /home
```

**Critical Gap:** Signup only creates `user` accounts. There is NO vendor signup path. A vendor would need to be manually promoted via `npm run set-role <uid> vendor` backend script.

**Source:** `lib/features/auth/signup_screen.dart`, `lib/services/firebase_auth_service.dart`

---

## 3. Current Login Flow

```
LoginScreen (email + password — NO role selection) ✅ CORRECT
    ↓
FirebaseAuthService.login(email, password)
    ↓
Firebase Auth returns UserCredential
    ↓
AuthStateNotifier reacts to idTokenChanges()
    ↓
reads Firebase Custom Claims role
    ↓
GoRouter redirects based on role
```

**Login screen is already correct.** No role selector. No admin input.

---

## 4. Current Role Storage

**Firebase Custom Claims (AUTHORITATIVE):**
```json
{ "role": "user" | "vendor" | "admin" }
```
- Set by: Firebase Admin SDK via `getAuth().setCustomUserClaims(uid, { role })`
- Tool: `src/scripts/setRole.ts` (run via `npm run set-role <uid> <role>`)
- Only accessible server-side (cannot be forged by client)

**Firestore `users/{uid}` (INFORMATIONAL):**
```json
{ "role": "user" | "vendor" | "admin" }
```
- Set to `'user'` on signup
- Updated by `setRole.ts` to mirror Custom Claims
- UserModel docstring explicitly notes: "Authorization MUST rely on Firebase Custom Claims, NOT this field."

---

## 5. Current Admin Authorization Mechanism

**Backend (`admin_routes.ts`):**
```typescript
requireAdmin middleware:
  1. Reads Authorization: Bearer <token>
  2. Calls getAuth().verifyIdToken(token) — Firebase Admin SDK
  3. Checks decodedToken.role !== "admin"
  4. Returns 403 if not admin
```
**This is secure.** Role is read from the verified Firebase ID token, not from request body.

**Frontend (`AuthStateNotifier`):**
```dart
// Role is NEVER from Firestore — always from Firebase Custom Claims
final claimRole = idTokenResult.claims?['role'] as String?;
```
**This is secure.** Client cannot inject roles.

**Admin Assignment:** Only via backend script `npm run set-role <uid> admin`.

---

## 6. Current Routing Behavior

| Role | On Login (isGoingToLoginOrSignup) | Admin Route Guard | Vendor Route Guard |
|---|---|---|---|
| `admin` | Redirected to `/admin` ⚠️ SHOULD BE `/home` | Allowed | Blocked → `/home` |
| `vendor` | Redirected to `/vendor` ✅ | Blocked → `/home` | Allowed |
| `user` | Redirected to `/home` ✅ | Blocked → `/home` | Blocked → `/home` |

**Issue:** Admin accounts bypass the user experience entirely. Per Phase 26 spec, admin should land on `/home` and access `/admin` from Profile.

---

## 7. Current Firestore Security Rules

```javascript
// users/{userId}
allow create: if request.resource.data.role == 'user';    // Signup ONLY creates 'user'
allow update: if isAdmin() || (isOwner && notModifying(['role', 'uid'])); // Role immutable client-side

// isAdmin() function reads Firebase Custom Claim:
function isAdmin() {
  return isAuthenticated() && request.auth.token.role == 'admin';
}
```

**Verdict:** Rules correctly prevent client-side role mutation. Users cannot self-promote to admin or vendor via Firestore.

**Gap for Vendor Signup:** Firestore rule for `vendors` collection:
```javascript
allow create: if isAdmin() || (isVendor() && request.resource.data.userId == request.auth.uid);
```
A new vendor signup writes to `users` with `role: 'user'`, but `isVendor()` checks the claim. The user won't have the `vendor` claim at signup time, so this blocks them from creating a vendor document unless admin-promoted first. **This blocks vendor self-registration.**

---

## 8. Admin Exposed in Frontend

| Location | Exposure | Security Risk |
|---|---|---|
| `app_router.dart:61` | `if (role == 'admin') return '/admin';` | Admin login lands on /admin not /home | Low |
| `app_router.dart:67` | `/admin` route guard blocks non-admin | ✅ CORRECT |
| `user_profile_view.dart:25` | Admin Dashboard button shown if `role == 'admin'` | ✅ CORRECT — role is from Custom Claims |
| `auth_state_notifier.dart:37` | `'admin'` in allowed roles list | ✅ CORRECT — read-only claim check |

**No public Admin signup UI exists.** No admin option in signup form. **LOGIN SCREEN HAS NO ROLE SELECTOR.** ✅

---

## 9. Security Weaknesses Discovered

| # | Issue | Severity | Fix Required |
|---|---|---|---|
| 1 | Admin login redirects to `/admin` instead of `/home` | **MEDIUM** | Change `app_router.dart` line 61 |
| 2 | No vendor signup path — all signups hardcoded as `role: 'user'` | **HIGH** | Add account type selector (User/Vendor only) to signup |
| 3 | Vendor signup writes `role: 'user'` to Firestore — vendor claim must still be set via backend | **MEDIUM** | Add vendor signup flow that creates vendor record + uses backend to set claim |
| 4 | Firestore rule: `users` create only allows `role == 'user'` — vendor signup needs backend-assisted flow | **MEDIUM** | Vendor signup must go through backend API, not direct Firestore write |
| 5 | `UserProfileView` is minimal — no My Events, Settings, WhatsApp links shown | **LOW** | Enhance profile UI |

---

## 10. Files That Need Modification

| File | Change Required |
|---|---|
| `lib/features/auth/signup_screen.dart` | Add User/Vendor account type selection. Remove admin option entirely. |
| `lib/services/firebase_auth_service.dart` | Add `signUpAsVendor()` method that creates vendor record via backend API |
| `lib/core/routing/app_router.dart` | Change admin login redirect from `/admin` → `/home` |
| `lib/features/user/profile/user_profile_view.dart` | Enhance profile UI with My Events, WhatsApp, Admin Dashboard (admin only), Sign Out |
| `eventology_backend/src/api/agent_routes.ts` OR new route | Add `POST /api/auth/register-vendor` endpoint for vendor signup |

---

## 11. Regression Risks

| Risk | Mitigations |
|---|---|
| Vendor signup changes break VendorSession | VendorSession is loaded from `VendorRepository.getVendorByUserId(uid)` — unaffected by signup changes |
| Admin routing change breaks admin access | Admin can access `/admin` from Profile → low risk |
| New backend vendor registration API breaks existing vendor flow | Additive — existing vendors unaffected |
| Firestore rule for vendor create requires `isVendor()` claim | Vendor signup must be 2-step: Firebase Auth → backend sets vendor claim → Firestore vendor doc |

---

## Summary: What Is Already Correct

✅ Login screen has no role selector  
✅ Admin is NOT in signup UI  
✅ `AuthStateNotifier` reads role from Firebase Custom Claims, not Firestore  
✅ Backend `requireAdmin` verifies Firebase ID token  
✅ Firestore rules prevent client-side role mutation  
✅ `setRole.ts` backend script exists for admin assignment  
✅ Admin route is guarded (`/admin` → redirects non-admins to `/home`)  
✅ Admin Dashboard button visible only when `role == 'admin'`

## Summary: What Needs Changing

❌ Admin login should redirect to `/home` not `/admin`  
❌ Signup needs User/Vendor account type selection  
❌ Vendor signup path doesn't exist — all accounts become users  
❌ Profile UI needs enhancement with navigation links + admin entry point  
❌ Backend needs `/api/auth/register-vendor` to handle vendor signup (claim + Firestore vendor doc)
