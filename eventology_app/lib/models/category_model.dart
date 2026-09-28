import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: categories/{categoryId}
/// Database: user-data
class CategoryModel {
  final String categoryId;
  final String name;
  final String? description;
  final String type;
  final bool active;
  final Timestamp createdAt;

  const CategoryModel({
    required this.categoryId,
    required this.name,
    this.description,
    required this.type,
    required this.active,
    required this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      categoryId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      type: data['type'] as String? ?? 'service',
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'type': type,
      'active': active,
      'createdAt': createdAt,
    };
  }
}
