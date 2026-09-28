import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/location_model.dart';

class LocationRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.locations);

  static void _validateLocation(LocationModel location) {
    if (location.country.trim().isEmpty) {
      throw ArgumentError('Country is required');
    }
    if (location.state.trim().isEmpty) {
      throw ArgumentError('State is required');
    }
    if (location.city.trim().isEmpty) {
      throw ArgumentError('City is required');
    }
    
    // Basic pincode validation
    if (location.pincode.isNotEmpty) {
      final pincodeRegExp = RegExp(r'^[a-zA-Z0-9\s-]{3,10}$');
      if (!pincodeRegExp.hasMatch(location.pincode)) {
        throw ArgumentError('Invalid pincode format');
      }
    }

    // Latitude and longitude validation
    if (location.latitude < -90.0 || location.latitude > 90.0) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (location.longitude < -180.0 || location.longitude > 180.0) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
  }

  static Future<LocationModel> createLocation(LocationModel location) async {
    _validateLocation(location);

    final docRef = _col.doc(); // Generate new ID
    final newLocation = LocationModel(
      locationId: docRef.id,
      country: location.country,
      state: location.state,
      city: location.city,
      area: location.area,
      pincode: location.pincode,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    await docRef.set(newLocation.toFirestore());
    return newLocation;
  }

  static Future<LocationModel?> getLocation(String locationId) async {
    final doc = await _col.doc(locationId).get();
    if (!doc.exists) return null;
    return LocationModel.fromFirestore(doc);
  }

  static Future<void> updateLocation(LocationModel location) async {
    if (location.locationId.isEmpty) {
      throw ArgumentError('Location ID is required for updates');
    }
    _validateLocation(location);
    await _col.doc(location.locationId).update(location.toFirestore());
  }

  static Future<void> deleteLocation(String locationId) async {
    await _col.doc(locationId).delete();
  }

  static Stream<List<LocationModel>> streamLocations() {
    return _col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => LocationModel.fromFirestore(doc)).toList();
    });
  }
}
