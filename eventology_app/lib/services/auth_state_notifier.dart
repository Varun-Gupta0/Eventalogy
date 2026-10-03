import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A centralized state notifier that tracks both the authenticated user
/// and their server-verified custom role (admin, vendor, user).
class AuthStateNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _user;
  String _role = 'unauthorized';
  bool _isLoading = true;

  User? get user => _user;
  String? get userId => _user?.uid;
  String get role => _role;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthStateNotifier() {
    _auth.idTokenChanges().listen((User? user) async {
      _user = user;
      
      if (user == null) {
        _role = 'unauthorized';
        _isLoading = false;
        notifyListeners();
      } else {
        try {
          // Force refresh false first to avoid unnecessary network calls
          // The token will automatically refresh when custom claims are updated on the backend
          // if the user signs out/in, or after 1 hour.
          final idTokenResult = await user.getIdTokenResult();
          
          // The source of truth is the custom claim 'role' set by the Firebase Admin SDK
          final claimRole = idTokenResult.claims?['role'] as String?;
          
          if (claimRole != null && ['admin', 'vendor', 'user'].contains(claimRole)) {
            _role = claimRole;
          } else {
            _role = 'user'; // Fallback for new signups before claims exist
          }
        } catch (e) {
          _role = 'user'; // Safe fallback
        }
        
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// Forces a refresh of the Firebase ID token to detect newly assigned Custom Claims.
  Future<void> refreshRoleClaims() async {
    if (_user == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Fetch a new token to get the latest custom claims from the server
      final idTokenResult = await _user!.getIdTokenResult(true);
      final claimRole = idTokenResult.claims?['role'] as String?;
      
      if (claimRole != null && ['admin', 'vendor', 'user'].contains(claimRole)) {
        _role = claimRole;
      } else {
        _role = 'user';
      }
    } catch (e) {
      // In case of network errors or missing claims
      _role = 'user';
    }
    
    _isLoading = false;
    notifyListeners();
  }
}

/// Global singleton instance to feed GoRouter and UI seamlessly
final authStateNotifier = AuthStateNotifier();
