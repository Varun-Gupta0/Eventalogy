import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/venue_model.dart';

/// Repository for venues/{venueId} in the user-data Firestore database.
class VenueRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.venues);

  static Future<String> createVenue(VenueModel venue) async {
    final ref = _col.doc();
    final data = venue.toFirestore();
    data['venueId'] = ref.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<VenueModel?> getVenue(String venueId) async {
    final doc = await _col.doc(venueId).get();
    if (!doc.exists) return null;
    return VenueModel.fromFirestore(doc);
  }

  static Stream<List<VenueModel>> streamVenues() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => VenueModel.fromFirestore(d)).toList());
  }

  static Stream<List<VenueModel>> streamActiveVenues() {
    return _col
        .where('status', isEqualTo: 'active')
        .where('verified', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => VenueModel.fromFirestore(d)).toList());
  }

  static Stream<List<VenueModel>> streamVenuesByType(String venueTypeId) {
    return _col
        .where('venueTypeId', isEqualTo: venueTypeId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map((d) => VenueModel.fromFirestore(d)).toList());
  }

  static Future<void> updateVenue(VenueModel venue) async {
    final updates = venue.toFirestore();
    updates.remove('createdAt'); // don't overwrite createdAt
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(venue.venueId).update(updates);
  }

  static Future<void> deleteVenue(String venueId) async {
    await _col.doc(venueId).delete();
  }
}
