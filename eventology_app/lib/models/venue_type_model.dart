import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: venueTypes/{venueTypeId}
/// Database: user-data
///
/// Examples: Banquet Hall, Hotel, Resort, Lawn, Convention Centre, etc.
class VenueTypeModel {
  final String venueTypeId;
  final String name;
  final String? description;
  final bool active;

  const VenueTypeModel({
    required this.venueTypeId,
    required this.name,
    this.description,
    required this.active,
  });

  factory VenueTypeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VenueTypeModel(
      venueTypeId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'active': active,
    };
  }
}
