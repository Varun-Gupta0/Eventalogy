import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String customerId;
  final String eventTypeId;
  final String title;
  final Timestamp eventDate;
  final int? guestCount;
  final double? budget;
  final String? locationId;
  final String? venueId;
  final Map<String, dynamic>? requirements;
  final String status;
  final String? paymentStatus;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const EventModel({
    required this.eventId,
    required this.customerId,
    required this.eventTypeId,
    required this.title,
    required this.eventDate,
    this.guestCount,
    this.budget,
    this.locationId,
    this.venueId,
    this.requirements,
    required this.status,
    this.paymentStatus,
    required this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EventModel(
      eventId: data['eventId'] as String? ?? doc.id,
      customerId: data['customerId'] as String? ?? '',
      eventTypeId: data['eventTypeId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      eventDate: data['eventDate'] as Timestamp? ?? Timestamp.now(),
      guestCount: data['guestCount'] as int?,
      budget: (data['budget'] as num?)?.toDouble(),
      locationId: data['locationId'] as String?,
      venueId: data['venueId'] as String?,
      requirements: data['requirements'] != null ? Map<String, dynamic>.from(data['requirements'] as Map) : null,
      status: data['status'] as String? ?? '',
      paymentStatus: data['paymentStatus'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'customerId': customerId,
      'eventTypeId': eventTypeId,
      'title': title,
      'eventDate': eventDate,
      if (guestCount != null) 'guestCount': guestCount,
      if (budget != null) 'budget': budget,
      if (locationId != null) 'locationId': locationId,
      if (venueId != null) 'venueId': venueId,
      if (requirements != null) 'requirements': requirements,
      'status': status,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  EventModel copyWith({
    String? eventId,
    String? customerId,
    String? eventTypeId,
    String? title,
    Timestamp? eventDate,
    int? guestCount,
    double? budget,
    String? locationId,
    String? venueId,
    Map<String, dynamic>? requirements,
    String? status,
    String? paymentStatus,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      customerId: customerId ?? this.customerId,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      guestCount: guestCount ?? this.guestCount,
      budget: budget ?? this.budget,
      locationId: locationId ?? this.locationId,
      venueId: venueId ?? this.venueId,
      requirements: requirements ?? this.requirements,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
