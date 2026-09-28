import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/category_model.dart';
import '../../models/event_type_model.dart';
import '../../models/venue_type_model.dart';

/// Repository for master reference data:
/// categories, eventTypes, venueTypes
///
/// Also contains seed operations for initial platform data.
/// Seed operations use existence checks to avoid overwriting production records.
class MasterDataRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  // ── CATEGORIES ──────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection(Collections.categories);

  static Stream<List<CategoryModel>> streamActiveCategories() {
    return _categories
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }

  // ── EVENT TYPES ──────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _eventTypes =>
      _db.collection(Collections.eventTypes);

  static Stream<List<EventTypeModel>> streamActiveEventTypes() {
    return _eventTypes
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => EventTypeModel.fromFirestore(d)).toList());
  }

  // ── VENUE TYPES ──────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _venueTypes =>
      _db.collection(Collections.venueTypes);

  static Stream<List<VenueTypeModel>> streamActiveVenueTypes() {
    return _venueTypes
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => VenueTypeModel.fromFirestore(d)).toList());
  }

  // ── SEED DATA ────────────────────────────────────────────────────────────

  /// Seeds initial standard ERP categories if they do not exist.
  /// Uses name checks — will NOT overwrite or duplicate existing production data.
  static Future<void> seedCategories() async {
    final existing = await _categories.get();
    final existingNames = existing.docs.map((d) => (d.data()['name'] as String?)?.toLowerCase() ?? '').toSet();

    final batch = _db.batch();
    const standardCategories = [
      {'name': 'Photography', 'description': 'Photography services for events and celebrations.'},
      {'name': 'Catering', 'description': 'Food and beverage services for events.'},
      {'name': 'Decoration', 'description': 'Event decoration, floral, styling and venue setup services.'},
      {'name': 'Entertainment', 'description': 'Entertainment services including DJs, performers, music and live acts.'},
      {'name': 'Beauty', 'description': 'Beauty, makeup, hairstyling and grooming services for events.'},
      {'name': 'Transportation', 'description': 'Transportation and travel services for event guests and organizers.'},
      {'name': 'Invitation', 'description': 'Physical and digital invitation design and related services.'},
    ];

    for (final cat in standardCategories) {
      if (!existingNames.contains(cat['name']!.toLowerCase())) {
        final ref = _categories.doc();
        batch.set(ref, {
          'name': cat['name'],
          'description': cat['description'],
          'type': 'service',
          'active': true,
          'createdAt': FieldValue.serverTimestamp()
        });
      }
    }
    await batch.commit();
  }

  /// Seeds initial event types if the collection is empty.
  static Future<void> seedEventTypes() async {
    final existing = await _eventTypes.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    const seedEventTypes = [
      'Wedding', 'Birthday', 'Corporate Event', 'Conference',
      'Engagement', 'Anniversary', 'Baby Shower', 'College Event', 'Party',
    ];
    for (final name in seedEventTypes) {
      final ref = _eventTypes.doc();
      batch.set(ref, {
        'name': name,
        'suggestedServiceIds': <String>[],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Seeds initial venue types if the collection is empty.
  static Future<void> seedVenueTypes() async {
    final existing = await _venueTypes.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    const seedVenueTypes = [
      'Banquet Hall', 'Hotel', 'Resort', 'Lawn', 'Convention Centre',
      'Community Hall', 'Restaurant', 'Rooftop', 'Outdoor Venue', 'Stadium', 'College Campus',
    ];
    for (final name in seedVenueTypes) {
      final ref = _venueTypes.doc();
      batch.set(ref, {'name': name, 'active': true});
    }
    await batch.commit();
  }

  /// Run all seed operations. Safe to call multiple times.
  static Future<void> seedAll() async {
    await seedCategories();
    await seedEventTypes();
    await seedVenueTypes();
  }
}
