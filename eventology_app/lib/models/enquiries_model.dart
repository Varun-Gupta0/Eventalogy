import 'package:cloud_firestore/cloud_firestore.dart';

class EnquiryModel {
  final String enquiryId;
  final String eventId;
  final String customerId;
  final String vendorId;
  final String serviceId;
  final String message;
  final Map<String, dynamic>? requirements;
  final Timestamp requestedDate;
  final String status;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const EnquiryModel({
    required this.enquiryId,
    required this.eventId,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    required this.message,
    this.requirements,
    required this.requestedDate,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory EnquiryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EnquiryModel(
      enquiryId: data['enquiryId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      vendorId: data['vendorId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      requirements: data['requirements'] != null ? Map<String, dynamic>.from(data['requirements'] as Map) : null,
      requestedDate: data['requestedDate'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enquiryId': enquiryId,
      'eventId': eventId,
      'customerId': customerId,
      'vendorId': vendorId,
      'serviceId': serviceId,
      'message': message,
      if (requirements != null) 'requirements': requirements,
      'requestedDate': requestedDate,
      'status': status,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  EnquiryModel copyWith({
    String? enquiryId,
    String? eventId,
    String? customerId,
    String? vendorId,
    String? serviceId,
    String? message,
    Map<String, dynamic>? requirements,
    Timestamp? requestedDate,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return EnquiryModel(
      enquiryId: enquiryId ?? this.enquiryId,
      eventId: eventId ?? this.eventId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      serviceId: serviceId ?? this.serviceId,
      message: message ?? this.message,
      requirements: requirements ?? this.requirements,
      requestedDate: requestedDate ?? this.requestedDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get id => enquiryId;
  Timestamp get targetDate => requestedDate;
}
