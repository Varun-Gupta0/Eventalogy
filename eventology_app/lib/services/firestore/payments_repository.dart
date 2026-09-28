import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/payments_model.dart';

class PaymentsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('payments');

  static Future<String> create(PaymentModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['paymentId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<PaymentModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PaymentModel.fromFirestore(doc);
  }

  static Stream<List<PaymentModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }

  static Future<void> update(PaymentModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.paymentId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
