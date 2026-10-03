import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/bookings_model.dart';

class BookingsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bookings');

  static Future<String> create(BookingModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['bookingId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<BookingModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return BookingModel.fromFirestore(doc);
  }

  static Stream<List<BookingModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
  }

  static Future<void> update(BookingModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.bookingId).update(updates);
  }

  static Stream<List<BookingModel>> streamVendorBookings(String vendorId) {
    return _col
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
  }

  static Stream<List<BookingModel>> streamEventBookings(String eventId) {
    return _col
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d)).toList());
  }

  static Future<void> confirmBooking(String id) async {
    return _db.runTransaction((transaction) async {
      final docRef = _col.doc(id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Booking not found");
      
      final data = snapshot.data()!;
      if (data['status'] != 'pending') {
        throw Exception("Only pending bookings can be confirmed");
      }
      
      transaction.update(docRef, {
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> rejectBooking(String id) async {
    return _db.runTransaction((transaction) async {
      final docRef = _col.doc(id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception("Booking not found");
      
      final data = snapshot.data()!;
      if (data['status'] != 'pending') {
        throw Exception("Only pending bookings can be rejected");
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
