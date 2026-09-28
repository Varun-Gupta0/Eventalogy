import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/agent_tasks_model.dart';

class AgentTasksRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('agent_tasks');

  static Future<String> create(AgentTaskModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['taskId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<AgentTaskModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AgentTaskModel.fromFirestore(doc);
  }

  static Stream<List<AgentTaskModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => AgentTaskModel.fromFirestore(d)).toList());
  }

  static Future<void> update(AgentTaskModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.taskId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
