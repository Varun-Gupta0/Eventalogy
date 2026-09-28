import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/auth_state_notifier.dart';
import '../../../core/widgets/primary_button.dart';

class UserProfileView extends StatelessWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final role = authStateNotifier.role;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('User Profile (Role: $role)'),
              const SizedBox(height: 32),
              
              if (role == 'admin') ...[
                PrimaryButton(
                  text: 'Admin Dashboard',
                  onPressed: () {
                    context.push('/admin');
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (role == 'vendor') ...[
                PrimaryButton(
                  text: 'Vendor Dashboard',
                  onPressed: () {
                    context.push('/vendor');
                  },
                ),
                const SizedBox(height: 16),
              ],

              PrimaryButton(
                text: 'Log Out',
                onPressed: () async {
                  await FirebaseAuthService.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

