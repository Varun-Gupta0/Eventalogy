import 'package:cloud_firestore/cloud_firestore.dart';

class AllocationModel {
  final String allocationId;
  final String eventId;
  final String? vendorId;
  final String? venueId;
  final String? serviceId;
  final String assignedBy;
  final String status;
  final Timestamp startTime;
  final Timestamp endTime;
  final Timestamp createdAt;

  const AllocationModel({
    required this.allocationId,
    required this.eventId,
    this.vendorId,
    this.venueId,
    this.serviceId,
    required this.assignedBy,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory AllocationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AllocationModel(
      allocationId: data['allocationId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      vendorId: data['vendorId'] as String?,
      venueId: data['venueId'] as String?,
      serviceId: data['serviceId'] as String?,
      assignedBy: data['assignedBy'] as String? ?? '',
      status: data['status'] as String? ?? '',
      startTime: data['startTime'] as Timestamp? ?? Timestamp.now(),
      endTime: data['endTime'] as Timestamp? ?? Timestamp.now(),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'allocationId': allocationId,
      'eventId': eventId,
      if (vendorId != null) 'vendorId': vendorId,
      if (venueId != null) 'venueId': venueId,
      if (serviceId != null) 'serviceId': serviceId,
      'assignedBy': assignedBy,
      'status': status,
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': createdAt,
    };
  }

  AllocationModel copyWith({
    String? allocationId,
    String? eventId,
    String? vendorId,
    String? venueId,
    String? serviceId,
    String? assignedBy,
    String? status,
    Timestamp? startTime,
    Timestamp? endTime,
    Timestamp? createdAt,
  }) {
    return AllocationModel(
      allocationId: allocationId ?? this.allocationId,
      eventId: eventId ?? this.eventId,
      vendorId: vendorId ?? this.vendorId,
      venueId: venueId ?? this.venueId,
      serviceId: serviceId ?? this.serviceId,
      assignedBy: assignedBy ?? this.assignedBy,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
