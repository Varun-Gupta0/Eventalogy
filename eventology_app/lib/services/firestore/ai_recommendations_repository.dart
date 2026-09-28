import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/ai_recommendations_model.dart';

class AiRecommendationsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ai_recommendations');

  static Future<String> create(AiRecommendationModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['recommendationId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<AiRecommendationModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AiRecommendationModel.fromFirestore(doc);
  }

  static Stream<List<AiRecommendationModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => AiRecommendationModel.fromFirestore(d)).toList());
  }

  static Future<void> update(AiRecommendationModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.recommendationId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
