import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/allocations_model.dart';

class AllocationsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('allocations');

  static Future<String> create(AllocationModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['allocationId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<AllocationModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return AllocationModel.fromFirestore(doc);
  }

  static Stream<List<AllocationModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => AllocationModel.fromFirestore(d)).toList());
  }

  static Future<void> update(AllocationModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.allocationId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
