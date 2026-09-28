import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore model for: eventTypes/{eventTypeId}
/// Database: user-data
///
/// Relationships:
/// - suggestedServiceIds -> services/{serviceId}
class EventTypeModel {
  final String eventTypeId;
  final String name;
  final String? description;
  final Map<String, dynamic>? defaultGuestRange;
  final List<String> suggestedServiceIds;
  final bool active;
  final Timestamp createdAt;

  const EventTypeModel({
    required this.eventTypeId,
    required this.name,
    this.description,
    this.defaultGuestRange,
    this.suggestedServiceIds = const [],
    required this.active,
    required this.createdAt,
  });

  factory EventTypeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventTypeModel(
      eventTypeId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      defaultGuestRange: data['defaultGuestRange'] as Map<String, dynamic>?,
      suggestedServiceIds: List<String>.from(data['suggestedServiceIds'] as List? ?? []),
      active: data['active'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (defaultGuestRange != null) 'defaultGuestRange': defaultGuestRange,
      'suggestedServiceIds': suggestedServiceIds,
      'active': active,
      'createdAt': createdAt,
    };
  }
}
