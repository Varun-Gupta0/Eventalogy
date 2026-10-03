import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/auth_state_notifier.dart';
import '../../core/config/api_config.dart';

/// The two public account types users can select during signup.
/// Admin is intentionally excluded — it is a backend-assigned privilege.
enum _AccountType { user, vendor }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();

  _AccountType _selectedType = _AccountType.user;
  bool _isLoading = false;

  // Backend base URL — unified for all local development platforms
  static const String _backendUrl = ApiConfig.baseUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final businessName = _businessNameController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all required fields');
      return;
    }

    if (_selectedType == _AccountType.vendor && businessName.isEmpty) {
      _showError('Please enter your business name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedType == _AccountType.user) {
        await _signUpAsUser(name, email, password);
      } else {
        await _signUpAsVendor(name, email, password, businessName);
      }
      // Navigation handled by GoRouter redirect reacting to authStateNotifier
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Creates a normal user account.
  /// Firestore is written directly from the client (role: 'user' — per security rules).
  Future<void> _signUpAsUser(String name, String email, String password) async {
    await FirebaseAuthService.signUp(email: email, password: password, name: name);
  }

  /// Creates a vendor account via a 2-step process:
  ///   1. Firebase Auth account created client-side (standard signup)
  ///   2. Backend sets vendor Custom Claim + creates vendor document
  ///      This prevents client-side role assignment — vendor privilege is server-assigned.
  Future<void> _signUpAsVendor(
    String name,
    String email,
    String password,
    String businessName,
  ) async {
    // Step 1: Create Firebase Auth account (writes role: 'user' to Firestore initially)
    await FirebaseAuthService.signUp(email: email, password: password, name: name);

    // Step 2: Get the fresh ID token for the newly created account
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Authentication failed. Please try again.');

    final idToken = await user.getIdToken();

    // Step 3: Call backend to set vendor claim + create vendor Firestore document
    final response = await http.post(
      Uri.parse('$_backendUrl/api/auth/register-vendor'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'businessName': businessName,
        'ownerName': name,
        'categoryIds': [], // Vendor can set categories after signup
      }),
    );

    if (response.statusCode == 201) {
      // Step 4: Force-refresh token so the vendor claim takes effect immediately
      await authStateNotifier.refreshRoleClaims();
    } else {
      // Parse backend error message
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Failed to create vendor account. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E2128), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.celebration_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create your Eventology account',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'I am joining as:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // ── Account Type Selector ─────────────────────────────────
                  // IMPORTANT: Only User and Vendor are shown.
                  // Admin is a backend-assigned privilege — never selectable here.
                  Row(
                    children: [
                      Expanded(
                        child: _AccountTypeCard(
                          type: _AccountType.user,
                          selected: _selectedType == _AccountType.user,
                          icon: Icons.person_rounded,
                          title: 'User',
                          subtitle:
                              'Plan events, discover venues, and work with the AI Event Architect.',
                          onTap: () =>
                              setState(() => _selectedType = _AccountType.user),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AccountTypeCard(
                          type: _AccountType.vendor,
                          selected: _selectedType == _AccountType.vendor,
                          icon: Icons.store_rounded,
                          title: 'Vendor',
                          subtitle:
                              'List your services, receive enquiries, and manage event bookings.',
                          onTap: () =>
                              setState(() => _selectedType = _AccountType.vendor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Form Fields ───────────────────────────────────────────
                  CustomTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your name',
                  ),
                  const SizedBox(height: 16),

                  // Business name — only visible for Vendor signup
                  if (_selectedType == _AccountType.vendor) ...[
                    CustomTextField(
                      controller: _businessNameController,
                      label: 'Business Name',
                      hint: 'Enter your business name',
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter your email',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 32),

                  PrimaryButton(
                    text: _selectedType == _AccountType.vendor
                        ? 'Create Vendor Account'
                        : 'Create Account',
                    onPressed: _handleSignup,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),

                  if (_selectedType == _AccountType.vendor) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Vendor accounts are reviewed before receiving enquiries.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card widget representing a selectable account type.
/// Only used for User and Vendor — Admin is intentionally excluded.
class _AccountTypeCard extends StatelessWidget {
  final _AccountType type;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.type,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.glassBorder,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppColors.primary.withAlpha(26)
              : AppColors.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.glassBorder,
                      width: 2,
                    ),
                    color: selected ? AppColors.primary : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.black, size: 12)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
