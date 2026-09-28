import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/agent_logs_model.dart';

class AgentLogsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('agent_logs');

  static Future<String> create(AgentLogModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['logId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<AgentLogModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AgentLogModel.fromFirestore(doc);
  }

  static Stream<List<AgentLogModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => AgentLogModel.fromFirestore(d)).toList());
  }

  static Future<void> update(AgentLogModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.logId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
