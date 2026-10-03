import 'package:cloud_firestore/cloud_firestore.dart';

class VendorModel {
  final String vendorId;
  final String userId;
  final String businessName;
  final String ownerName;
  final String? description;
  final List<String> categoryIds;
  final List<String>? serviceIds;
  final String? locationId;
  final String? phone;
  final String? email;
  final String? pricingModel;
  final List<String>? portfolioImages;
  final double? rating;
  final bool verified;
  final String status;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  VendorModel({
    required this.vendorId,
    required this.userId,
    required this.businessName,
    required this.ownerName,
    this.description,
    required this.categoryIds,
    this.serviceIds,
    this.locationId,
    this.phone,
    this.email,
    this.pricingModel,
    this.portfolioImages,
    this.rating,
    required this.verified,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory VendorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorModel(
      vendorId: data['vendorId'] as String? ?? doc.id,
      userId: data['userId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      description: data['description'] as String?,
      categoryIds: List<String>.from(data['categoryIds'] ?? []),
      serviceIds: data['serviceIds'] != null ? List<String>.from(data['serviceIds']) : null,
      locationId: data['locationId'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      pricingModel: data['pricingModel'] as String?,
      portfolioImages: data['portfolioImages'] != null ? List<String>.from(data['portfolioImages']) : null,
      rating: (data['rating'] as num?)?.toDouble(),
      verified: data['verified'] as bool? ?? false,
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vendorId': vendorId,
      'userId': userId,
      'businessName': businessName,
      'ownerName': ownerName,
      if (description != null) 'description': description,
      'categoryIds': categoryIds,
      if (serviceIds != null) 'serviceIds': serviceIds,
      if (locationId != null) 'locationId': locationId,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (pricingModel != null) 'pricingModel': pricingModel,
      if (portfolioImages != null) 'portfolioImages': portfolioImages,
      if (rating != null) 'rating': rating,
      'verified': verified,
      'status': status,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  VendorModel copyWith({
    String? vendorId,
    String? userId,
    String? businessName,
    String? ownerName,
    String? description,
    List<String>? categoryIds,
    List<String>? serviceIds,
    String? locationId,
    String? phone,
    String? email,
    String? pricingModel,
    List<String>? portfolioImages,
    double? rating,
    bool? verified,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return VendorModel(
      vendorId: vendorId ?? this.vendorId,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      description: description ?? this.description,
      categoryIds: categoryIds ?? this.categoryIds,
      serviceIds: serviceIds ?? this.serviceIds,
      locationId: locationId ?? this.locationId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      pricingModel: pricingModel ?? this.pricingModel,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get id => vendorId;
  List<String> get mediaGallery => portfolioImages ?? [];
  String? get vendorType => categoryIds.isNotEmpty ? categoryIds.first : null;
  double? get basePrice => 0.0; // Placeholder for basePrice
}
