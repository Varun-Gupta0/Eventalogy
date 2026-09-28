import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/notifications_model.dart';

class NotificationsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  static Future<String> create(NotificationModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['notificationId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<NotificationModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return NotificationModel.fromFirestore(doc);
  }

  static Stream<List<NotificationModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => NotificationModel.fromFirestore(d)).toList());
  }

  static Future<void> update(NotificationModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.notificationId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
