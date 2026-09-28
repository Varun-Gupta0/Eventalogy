import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: venues/{venueId}
/// Database: user-data
class VenueModel {
  final String venueId;
  final String name;
  final String? description;
  final String venueTypeId;
  final String locationId;
  final int capacity;
  final double? priceFrom;
  final double? priceTo;
  final List<String> amenities;
  final List<String> images;
  final String? contactName;
  final String? contactPhone;
  final String status;
  final bool verified;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const VenueModel({
    required this.venueId,
    required this.name,
    this.description,
    required this.venueTypeId,
    required this.locationId,
    required this.capacity,
    this.priceFrom,
    this.priceTo,
    this.amenities = const [],
    this.images = const [],
    this.contactName,
    this.contactPhone,
    required this.status,
    required this.verified,
    required this.createdAt,
    this.updatedAt,
  });

  factory VenueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VenueModel(
      venueId: data['venueId'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      venueTypeId: data['venueTypeId'] as String? ?? '',
      locationId: data['locationId'] as String? ?? '',
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      priceFrom: (data['priceFrom'] as num?)?.toDouble(),
      priceTo: (data['priceTo'] as num?)?.toDouble(),
      amenities: List<String>.from(data['amenities'] as List? ?? []),
      images: List<String>.from(data['images'] as List? ?? []),
      contactName: data['contactName'] as String?,
      contactPhone: data['contactPhone'] as String?,
      status: data['status'] as String? ?? 'pending',
      verified: data['verified'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'venueId': venueId,
      'name': name,
      if (description != null) 'description': description,
      'venueTypeId': venueTypeId,
      'locationId': locationId,
      'capacity': capacity,
      if (priceFrom != null) 'priceFrom': priceFrom,
      if (priceTo != null) 'priceTo': priceTo,
      'amenities': amenities,
      'images': images,
      if (contactName != null) 'contactName': contactName,
      if (contactPhone != null) 'contactPhone': contactPhone,
      'status': status,
      'verified': verified,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  VenueModel copyWith({
    String? venueId,
    String? name,
    String? description,
    String? venueTypeId,
    String? locationId,
    int? capacity,
    double? priceFrom,
    double? priceTo,
    List<String>? amenities,
    List<String>? images,
    String? contactName,
    String? contactPhone,
    String? status,
    bool? verified,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return VenueModel(
      venueId: venueId ?? this.venueId,
      name: name ?? this.name,
      description: description ?? this.description,
      venueTypeId: venueTypeId ?? this.venueTypeId,
      locationId: locationId ?? this.locationId,
      capacity: capacity ?? this.capacity,
      priceFrom: priceFrom ?? this.priceFrom,
      priceTo: priceTo ?? this.priceTo,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
