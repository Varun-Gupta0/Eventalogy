import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String eventId;
  final String customerId;
  final String vendorId;
  final String serviceId;
  final String? venueId;
  final String? packageId;
  final double amount;
  final String status;
  final String paymentStatus;
  final Timestamp bookingDate;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const BookingModel({
    required this.bookingId,
    required this.eventId,
    required this.customerId,
    required this.vendorId,
    required this.serviceId,
    this.venueId,
    this.packageId,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.bookingDate,
    required this.createdAt,
    this.updatedAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BookingModel(
      bookingId: data['bookingId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      vendorId: data['vendorId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      venueId: data['venueId'] as String?,
      packageId: data['packageId'] as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? '',
      paymentStatus: data['paymentStatus'] as String? ?? '',
      bookingDate: data['bookingDate'] as Timestamp? ?? Timestamp.now(),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookingId': bookingId,
      'eventId': eventId,
      'customerId': customerId,
      'vendorId': vendorId,
      'serviceId': serviceId,
      if (venueId != null) 'venueId': venueId,
      if (packageId != null) 'packageId': packageId,
      'amount': amount,
      'status': status,
      'paymentStatus': paymentStatus,
      'bookingDate': bookingDate,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  BookingModel copyWith({
    String? bookingId,
    String? eventId,
    String? customerId,
    String? vendorId,
    String? serviceId,
    String? venueId,
    String? packageId,
    double? amount,
    String? status,
    String? paymentStatus,
    Timestamp? bookingDate,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      eventId: eventId ?? this.eventId,
      customerId: customerId ?? this.customerId,
      vendorId: vendorId ?? this.vendorId,
      serviceId: serviceId ?? this.serviceId,
      venueId: venueId ?? this.venueId,
      packageId: packageId ?? this.packageId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      bookingDate: bookingDate ?? this.bookingDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get id => bookingId;
  double get totalAmount => amount;
  Timestamp get targetDate => bookingDate;
}
