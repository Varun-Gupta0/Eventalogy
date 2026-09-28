import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase/firestore_config.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirestoreConfig.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        print('=== FIRESTORE DIAGNOSTICS START ===');
        print('Firebase Project ID: ${_firestore.app.options.projectId}');
        print('Database ID used by _firestore: user-data'); // Can't easily print _firestore.databaseId, hardcode to show intent
        print('Authenticated UID: $uid');
        print('Target Path: users/$uid');
        
        try {
          await _firestore.collection('users').doc(uid).set({
            'uid': uid,
            'email': email,
            'name': name,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Firestore write SUCCESS');
        } on FirebaseException catch (e) {
          print('Firestore write FAILED (FirebaseException):');
          print('Code: ${e.code}');
          print('Message: ${e.message}');
          print('Plugin: ${e.plugin}');
          rethrow;
        } catch (e) {
          print('Firestore write FAILED (Unknown): $e');
          rethrow;
        } finally {
          print('=== FIRESTORE DIAGNOSTICS END ===');
        }
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is FirebaseException) rethrow;
      throw Exception('An unexpected error occurred during signup: $e');
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Could not send reset email.');
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No user found for that email.');
      case 'wrong-password':
        return Exception('Wrong password provided for that user.');
      case 'invalid-credential':
        return Exception('Invalid email or password.');
      case 'email-already-in-use':
        return Exception('An account already exists for that email.');
      case 'invalid-email':
        return Exception('The email address is invalid.');
      case 'weak-password':
        return Exception('The password provided is too weak.');
      default:
        return Exception(e.message ?? 'Authentication failed.');
    }
  }
}
