import 'package:cloud_firestore/cloud_firestore.dart';

class PackageModel {
  final String packageId;
  final String name;
  final String? description;
  final List<String> serviceIds;
  final double price;
  final double? discount;
  final bool active;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const PackageModel({
    required this.packageId,
    required this.name,
    this.description,
    required this.serviceIds,
    required this.price,
    this.discount,
    required this.active,
    required this.createdAt,
    this.updatedAt,
  });

  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PackageModel(
      packageId: data['packageId'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      serviceIds: List<String>.from(data['serviceIds'] as List? ?? []),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble(),
      active: data['active'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'packageId': packageId,
      'name': name,
      if (description != null) 'description': description,
      'serviceIds': serviceIds,
      'price': price,
      if (discount != null) 'discount': discount,
      'active': active,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  PackageModel copyWith({
    String? packageId,
    String? name,
    String? description,
    List<String>? serviceIds,
    double? price,
    double? discount,
    bool? active,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return PackageModel(
      packageId: packageId ?? this.packageId,
      name: name ?? this.name,
      description: description ?? this.description,
      serviceIds: serviceIds ?? this.serviceIds,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
