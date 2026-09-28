import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: services/{serviceId}
/// Database: user-data
///
/// Relationships:
/// - categoryId -> categories/{categoryId}
class ServiceModel {
  final String serviceId;
  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String? description;
  final String pricingModel;
  final double? basePrice;
  final List<String> images;
  final bool active;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const ServiceModel({
    required this.serviceId,
    required this.name,
    required this.categoryId,
    this.subcategoryId,
    this.description,
    required this.pricingModel,
    this.basePrice,
    this.images = const [],
    required this.active,
    required this.createdAt,
    this.updatedAt,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      serviceId: data['serviceId'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      subcategoryId: data['subcategoryId'] as String?,
      description: data['description'] as String?,
      pricingModel: data['pricingModel'] as String? ?? 'fixed',
      basePrice: (data['basePrice'] as num?)?.toDouble(),
      images: List<String>.from(data['images'] as List? ?? []),
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'serviceId': serviceId,
      'name': name,
      'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      if (description != null) 'description': description,
      'pricingModel': pricingModel,
      if (basePrice != null) 'basePrice': basePrice,
      'images': images,
      'active': active,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
