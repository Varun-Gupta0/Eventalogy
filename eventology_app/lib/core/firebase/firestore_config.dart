import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreConfig {
  /// Returns the configured FirebaseFirestore instance for the 'user-data' database.
  static FirebaseFirestore get instance {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'user-data',
    );
  }
}
