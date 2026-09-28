import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/user_model.dart';

/// Repository for users/{uid} in the user-data Firestore database.
///
/// Security Note: The `role` field in Firestore is informational only.
/// Authorization uses Firebase Custom Claims, not Firestore role fields.
class UserRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.users);

  /// Get a user profile by UID.
  static Future<UserModel?> getUser(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream a user profile in real-time.
  static Stream<UserModel?> streamUser(String uid) {
    return _col.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Update a user's editable profile fields.
  /// NOTE: `role` and `uid` MUST NOT be updated from the client.
  static Future<void> updateProfile({
    required String uid,
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
    await _col.doc(uid).update(updates);
  }

  /// Admin only: list all users (paginated).
  static Future<List<UserModel>> listUsers({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _col.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }
}
