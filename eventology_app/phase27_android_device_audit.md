# PHASE 27A: ANDROID DEVICE AUDIT

## 1. Android Readiness
- **Project Structure**: Standard Flutter Android template is intact (`android/app/build.gradle.kts` uses namespace `com.eventology_app`).
- **Google Services**: `google-services.json` is present in `android/app/`.
- **AndroidManifest.xml**: Correctly configured. Needs validation around `usesCleartextTraffic` since we are doing local HTTP development. 127.0.0.1 is generally permitted for cleartext by default on recent Android, but if we switch to a LAN IP, it will fail without this flag.

## 2. Backend URL Configuration & Architecture
The current backend URL architecture is fragmented and hardcoded across several files:
- `lib/services/admin_api_service.dart`: `http://localhost:3000/api/admin`
- `lib/features/auth/signup_screen.dart`: `http://127.0.0.1:3000`
- `lib/features/user/ai/services/agent_chat_service.dart`: Checks `kIsWeb ? 'http://127.0.0.1:3000...' : 'http://10.0.2.2:3000...'`
- `lib/features/user/ai/services/ai_planner_service.dart`: Hardcoded `http://10.0.2.2:3000...`
- `lib/features/user/whatsapp/whatsapp_link_screen.dart`: Checks `kIsWeb` for `127.0.0.1` vs `10.0.2.2`.

**Issue for Physical Device**:
- `localhost` / `127.0.0.1` from the physical phone will route to the phone itself, NOT the laptop.
- `10.0.2.2` only works for the Android Emulator routing to the laptop. It fails on a physical device.

**Proposed Solution for USB Debugging**:
We will use **ADB Reverse Port Forwarding** (`adb reverse tcp:3000 tcp:3000`).
This elegantly bridges the physical phone's `localhost:3000` to the laptop's `localhost:3000`. 
This means we can unify all API calls to `http://127.0.0.1:3000` across ALL local platforms (Web, Emulator, Physical Phone).
We will create a centralized `ApiConfig` class to prevent this fragmentation.

## 3. Firebase Readiness
- `google-services.json` is present.
- Firebase Auth and Firestore do not require local network routing (they go straight to the cloud).

## 4. Risks
- Cleartext HTTP traffic might be blocked by Android 9+ network security config. Using `127.0.0.1` usually bypasses this, but we should verify. If blocked, we'll implement a debug-only network security config.
- `ai_planner_service.dart` is using an old unused endpoint (`/api/ai/generate-event-plan`) which isn't part of the current LangGraph architecture. We'll leave it alone unless it breaks the core flow.

## 5. Implementation Plan
1. Centralize the API URL into `lib/core/config/api_config.dart`.
2. Update all hardcoded references to use `ApiConfig.baseUrl`.
3. Check `flutter devices` and verify the physical Android device.
4. Run `adb reverse tcp:3000 tcp:3000` to bind the phone's port to the laptop.
5. Build, run, and smoke test on the physical device.
