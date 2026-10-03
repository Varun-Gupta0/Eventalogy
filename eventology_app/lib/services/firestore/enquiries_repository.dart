import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/enquiries_model.dart';

class EnquiriesRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('enquiries');

  static Future<String> create(EnquiryModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['enquiryId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<EnquiryModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return EnquiryModel.fromFirestore(doc);
  }

  static Stream<List<EnquiryModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => EnquiryModel.fromFirestore(d)).toList());
  }

  static Future<void> update(EnquiryModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.enquiryId).update(updates);
  }

  static Stream<List<EnquiryModel>> streamVendorEnquiries(String vendorId) {
    return _col
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => EnquiryModel.fromFirestore(d)).toList());
  }

  static Future<void> acceptEnquiry(String id) async {
    return _db.runTransaction((transaction) async {
      final docRef = _col.doc(id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Enquiry not found");
      
      final data = snapshot.data()!;
      if (data['status'] != 'pending') {
        throw Exception("Only pending enquiries can be accepted");
      }
      
      transaction.update(docRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> declineEnquiry(String id) async {
    return _db.runTransaction((transaction) async {
      final docRef = _col.doc(id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Enquiry not found");
      
      final data = snapshot.data()!;
      if (data['status'] != 'pending') {
        throw Exception("Only pending enquiries can be declined");
      }
      
      transaction.update(docRef, {
        'status': 'declined',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
