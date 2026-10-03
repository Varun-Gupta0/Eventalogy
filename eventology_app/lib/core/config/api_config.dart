class ApiConfig {
  /// Base URL for the backend API.
  /// 
  /// For local development on a physical Android device, use `adb reverse tcp:3000 tcp:3000`
  /// to forward the device's local port 3000 to the laptop's localhost.
  /// 
  /// This unified URL works across Web, Desktop, and Physical Android (with adb reverse).
  /// For Android Emulator without adb reverse, you would typically use `10.0.2.2`.
  /// Uses dart environment variables with a fallback to 127.0.0.1
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );
}
