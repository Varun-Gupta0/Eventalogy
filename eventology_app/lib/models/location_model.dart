import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: locations/{locationId}
/// Database: user-data
///
/// Used for: venue location, vendor location, event location,
/// geographic search, future distance calculations.
class LocationModel {
  final String locationId;
  final String country;
  final String state;
  final String city;
  final String area;
  final String pincode;
  final double latitude;
  final double longitude;

  const LocationModel({
    required this.locationId,
    required this.country,
    required this.state,
    required this.city,
    required this.area,
    required this.pincode,
    required this.latitude,
    required this.longitude,
  });

  factory LocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LocationModel(
      locationId: doc.id,
      country: data['country'] as String? ?? '',
      state: data['state'] as String? ?? '',
      city: data['city'] as String? ?? '',
      area: data['area'] as String? ?? '',
      pincode: data['pincode'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'country': country,
      'state': state,
      'city': city,
      'area': area,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
