class AuthService {
  // Mock role resolution
  static Future<String> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network request
    if (email.contains('admin')) {
      return 'admin';
    }
    return 'user';
  }
}
