import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/vendor_model.dart';
import '../../models/venue_model.dart';
import '../../models/category_model.dart';
import '../../models/event_type_model.dart';
import '../../models/venue_type_model.dart';
import '../../models/location_model.dart';
import '../../core/database/collections.dart';

class CatalogRepository {
  static final _firestore = FirebaseFirestore.instance;

  static Stream<List<VendorModel>> streamFeaturedVendors({int limit = 5}) {
    return _firestore
        .collection(Collections.vendors)
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => VendorModel.fromFirestore(doc)).toList());
  }

  static Stream<List<VenueModel>> streamFeaturedVenues({int limit = 3}) {
    return _firestore
        .collection(Collections.venues)
        .where('status', isEqualTo: 'active')
        .where('verified', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => VenueModel.fromFirestore(doc)).toList());
  }

  static Stream<List<CategoryModel>> streamActiveCategories() {
    return _firestore
        .collection(Collections.categories)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList());
  }

  static Stream<List<EventTypeModel>> streamActiveEventTypes() {
    return _firestore
        .collection(Collections.eventTypes)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EventTypeModel.fromFirestore(doc)).toList());
  }

  static Stream<List<VendorModel>> streamVendorsByCategory(String categoryId, {String? locationId}) {
    var query = _firestore
        .collection(Collections.vendors)
        .where('status', isEqualTo: 'active')
        .where('categoryIds', arrayContains: categoryId);
    if (locationId != null) {
      query = query.where('locationId', isEqualTo: locationId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => VendorModel.fromFirestore(doc)).toList());
  }

  static Stream<List<VenueModel>> streamActiveVenues({String? venueTypeId, String? locationId, int? minCapacity}) {
    var query = _firestore
        .collection(Collections.venues)
        .where('status', isEqualTo: 'active')
        .where('verified', isEqualTo: true);
    
    if (venueTypeId != null) {
      query = query.where('venueTypeId', isEqualTo: venueTypeId);
    }
    if (locationId != null) {
      query = query.where('locationId', isEqualTo: locationId);
    }
    if (minCapacity != null) {
      query = query.where('capacity', isGreaterThanOrEqualTo: minCapacity);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) => VenueModel.fromFirestore(doc)).toList());
  }

  static Future<VenueModel?> getVenue(String venueId) async {
    final doc = await _firestore.collection(Collections.venues).doc(venueId).get();
    if (!doc.exists) return null;
    return VenueModel.fromFirestore(doc);
  }

  static Future<VendorModel?> getVendor(String vendorId) async {
    final doc = await _firestore.collection(Collections.vendors).doc(vendorId).get();
    if (!doc.exists) return null;
    return VendorModel.fromFirestore(doc);
  }

  static Future<CategoryModel?> getCategory(String categoryId) async {
    final doc = await _firestore.collection(Collections.categories).doc(categoryId).get();
    if (!doc.exists) return null;
    return CategoryModel.fromFirestore(doc);
  }

  static Future<VenueTypeModel?> getVenueType(String venueTypeId) async {
    final doc = await _firestore.collection(Collections.venueTypes).doc(venueTypeId).get();
    if (!doc.exists) return null;
    return VenueTypeModel.fromFirestore(doc);
  }

  static Future<LocationModel?> getLocation(String locationId) async {
    final doc = await _firestore.collection(Collections.locations).doc(locationId).get();
    if (!doc.exists) return null;
    return LocationModel.fromFirestore(doc);
  }

  static Future<EventTypeModel?> getEventType(String eventTypeId) async {
    final doc = await _firestore.collection(Collections.eventTypes).doc(eventTypeId).get();
    if (!doc.exists) return null;
    return EventTypeModel.fromFirestore(doc);
  }
}
