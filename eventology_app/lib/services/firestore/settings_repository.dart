import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/settings_model.dart';

class SettingsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('settings');

  static Future<String> create(SettingModel item) async {
    final ref = _col.doc(item.settingId) ;
    final data = item.toFirestore();
    data['settingId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<SettingModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return SettingModel.fromFirestore(doc);
  }

  static Stream<List<SettingModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => SettingModel.fromFirestore(d)).toList());
  }

  static Future<void> update(SettingModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.settingId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
