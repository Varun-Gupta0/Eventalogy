import 'package:cloud_firestore/cloud_firestore.dart';

class AiPlanModel {
  final String planId;
  final String eventId;
  final String userId;
  final Map<String, dynamic> eventRequirements;
  final List<dynamic> recommendations;
  final double estimatedBudget;
  final String status;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const AiPlanModel({
    required this.planId,
    required this.eventId,
    required this.userId,
    required this.eventRequirements,
    required this.recommendations,
    required this.estimatedBudget,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory AiPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AiPlanModel(
      planId: data['planId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      eventRequirements: Map<String, dynamic>.from(data['eventRequirements'] as Map? ?? {}),
      recommendations: List.from(data['recommendations'] as List? ?? []),
      estimatedBudget: (data['estimatedBudget'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'planId': planId,
      'eventId': eventId,
      'userId': userId,
      'eventRequirements': eventRequirements,
      'recommendations': recommendations,
      'estimatedBudget': estimatedBudget,
      'status': status,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  AiPlanModel copyWith({
    String? planId,
    String? eventId,
    String? userId,
    Map<String, dynamic>? eventRequirements,
    List<dynamic>? recommendations,
    double? estimatedBudget,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return AiPlanModel(
      planId: planId ?? this.planId,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      eventRequirements: eventRequirements ?? this.eventRequirements,
      recommendations: recommendations ?? this.recommendations,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
