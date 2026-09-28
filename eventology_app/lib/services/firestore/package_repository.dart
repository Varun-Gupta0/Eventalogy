import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/package_model.dart';

class PackageRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.packages);

  static Future<String> createPackage(PackageModel package) async {
    final ref = _col.doc();
    final data = package.toFirestore();
    data['packageId'] = ref.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<PackageModel?> getPackage(String packageId) async {
    final doc = await _col.doc(packageId).get();
    if (!doc.exists) return null;
    return PackageModel.fromFirestore(doc);
  }

  static Stream<List<PackageModel>> streamPackages() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => PackageModel.fromFirestore(d)).toList());
  }

  static Stream<List<PackageModel>> streamActivePackages() {
    return _col
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PackageModel.fromFirestore(d)).toList());
  }

  static Future<void> updatePackage(PackageModel package) async {
    final updates = package.toFirestore();
    updates.remove('createdAt');
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(package.packageId).update(updates);
  }

  static Future<void> deletePackage(String packageId) async {
    await _col.doc(packageId).delete();
  }
}
