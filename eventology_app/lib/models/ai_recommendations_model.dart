import 'package:cloud_firestore/cloud_firestore.dart';

class AiRecommendationModel {
  final String recommendationId;
  final String eventId;
  final String? serviceId;
  final String? vendorId;
  final String? venueId;
  final String reason;
  final double score;
  final String status;
  final Timestamp createdAt;

  const AiRecommendationModel({
    required this.recommendationId,
    required this.eventId,
    this.serviceId,
    this.vendorId,
    this.venueId,
    required this.reason,
    required this.score,
    required this.status,
    required this.createdAt,
  });

  factory AiRecommendationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AiRecommendationModel(
      recommendationId: data['recommendationId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      serviceId: data['serviceId'] as String?,
      vendorId: data['vendorId'] as String?,
      venueId: data['venueId'] as String?,
      reason: data['reason'] as String? ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recommendationId': recommendationId,
      'eventId': eventId,
      if (serviceId != null) 'serviceId': serviceId,
      if (vendorId != null) 'vendorId': vendorId,
      if (venueId != null) 'venueId': venueId,
      'reason': reason,
      'score': score,
      'status': status,
      'createdAt': createdAt,
    };
  }

  AiRecommendationModel copyWith({
    String? recommendationId,
    String? eventId,
    String? serviceId,
    String? vendorId,
    String? venueId,
    String? reason,
    double? score,
    String? status,
    Timestamp? createdAt,
  }) {
    return AiRecommendationModel(
      recommendationId: recommendationId ?? this.recommendationId,
      eventId: eventId ?? this.eventId,
      serviceId: serviceId ?? this.serviceId,
      vendorId: vendorId ?? this.vendorId,
      venueId: venueId ?? this.venueId,
      reason: reason ?? this.reason,
      score: score ?? this.score,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
