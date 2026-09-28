import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String eventId;
  final String customerId;
  final String vendorId;
  final String? venueId;
  final int rating;
  final String comment;
  final Timestamp createdAt;

  const ReviewModel({
    required this.reviewId,
    required this.eventId,
    required this.customerId,
    required this.vendorId,
    this.venueId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel(
      reviewId: data['reviewId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      vendorId: data['vendorId'] as String? ?? '',
      venueId: data['venueId'] as String?,
      rating: data['rating'] as int? ?? 0,
      comment: data['comment'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewId': reviewId,
      'eventId': eventId,
      'customerId': customerId,
      'vendorId': vendorId,
      if (venueId != null) 'venueId': venueId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
    };
  }

  ReviewModel copyWith({
    String? reviewId,
    String? eventId,
    String? customerId,
    String? vendorId,
    String? venueId,
    int? rating,
    String? comment,
    Timestamp? createdAt,
  }) {
    return ReviewModel(
      reviewId: reviewId ?? this.reviewId,
      eventId: eventId ?? this.eventId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      venueId: venueId ?? this.venueId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
