import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/ai_plans_model.dart';

class AiPlansRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ai_plans');

  static Future<String> create(AiPlanModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['planId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<AiPlanModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AiPlanModel.fromFirestore(doc);
  }

  static Stream<List<AiPlanModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => AiPlanModel.fromFirestore(d)).toList());
  }

  static Future<void> update(AiPlanModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.planId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
