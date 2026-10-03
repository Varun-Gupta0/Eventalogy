import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/events_model.dart';

class EventsRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('events');

  static Future<String> create(EventModel item) async {
    final ref = _col.doc() ;
    final data = item.toFirestore();
    data['eventId'] = ref.id;
    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    return ref.id;
  }

  static Future<EventModel?> get(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return EventModel.fromFirestore(doc);
  }

  static Stream<List<EventModel>> stream() {
    return _col
        .snapshots()
        .map((s) => s.docs.map((d) => EventModel.fromFirestore(d)).toList());
  }

  static Future<void> update(EventModel item) async {
    final updates = item.toFirestore();
    updates.remove('createdAt');
    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(item.eventId).update(updates);
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<EventModel?> getEvent(String id) => get(id);

  static Stream<List<EventModel>> streamUserEvents(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => EventModel.fromFirestore(d)).toList());
  }
}
