import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/api_config.dart';

/// Screen that allows an authenticated user to link their WhatsApp number
/// to their Eventology account.
///
/// Flow:
/// 1. User enters their WhatsApp phone number
/// 2. App calls POST /api/whatsapp/initiate-link
/// 3. User is prompted to send a WhatsApp message to the Eventology number
///    (this triggers the webhook to issue the token to the phone)
/// 4. User enters the 8-character code shown in the WhatsApp message
/// 5. App calls POST /api/whatsapp/link to complete linking
class WhatsAppLinkScreen extends StatefulWidget {
  const WhatsAppLinkScreen({super.key});

  @override
  State<WhatsAppLinkScreen> createState() => _WhatsAppLinkScreenState();
}

class _WhatsAppLinkScreenState extends State<WhatsAppLinkScreen> {
  final String baseUrl = '${ApiConfig.baseUrl}/api/whatsapp';

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _initiateLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; _error = null; });

    try {
      final idToken = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/initiate-link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'phoneNumber': _phoneCtrl.text.trim()}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        setState(() { _codeSent = true; _isLoading = false; });
      } else {
        setState(() {
          _error = data['error'] as String? ?? 'Failed to initiate linking.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; _isLoading = false; });
    }
  }

  Future<void> _confirmLink() async {
    final code = _tokenCtrl.text.trim();
    if (code.isEmpty) {
      setState(() { _error = 'Please enter the confirmation code.'; });
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final idToken = await _getToken();
      // Full hex token — but user enters 8-char uppercase preview.
      // We need to look up by the token prefix — handled server side.
      // In production you'd want to design this more robustly; for MVP
      // the user receives the full 64-char hex token in WhatsApp message
      // and enters only the first 8 chars. The server does a prefix search.
      // This is simplified — real flow: user gets the linking URL in WhatsApp
      // and navigates to it with the full token as query param (?code=...).
      final response = await http.post(
        Uri.parse('$baseUrl/link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'token': code}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        setState(() {
          _success = 'WhatsApp linked successfully! You can now use Eventology on WhatsApp.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['error'] as String? ?? 'Linking failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Link WhatsApp', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF25D366).withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat, color: Color(0xFF25D366), size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Link WhatsApp Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plan events via WhatsApp using the same AI Architect.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (_success != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_success!, style: const TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ] else if (!_codeSent) ...[
              // Step 1: Enter phone number
              const Text(
                'Step 1: Enter your WhatsApp number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the phone number registered on your WhatsApp account (include country code, e.g. +91).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                    if (v.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter a valid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _initiateLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ] else ...[
              // Step 2: Enter the confirmation code from WhatsApp
              const Text(
                'Step 2: Confirm via WhatsApp',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Send "Hi" to the Eventology WhatsApp number.\n'
                '2. You will receive a link — click it to complete linking.\n'
                '3. Or paste the full code from the link below.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tokenCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Confirmation Code (from WhatsApp link)',
                  prefixIcon: Icon(Icons.vpn_key, color: AppColors.primary),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Link Account', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() { _codeSent = false; _error = null; }),
                child: const Text('← Back', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
