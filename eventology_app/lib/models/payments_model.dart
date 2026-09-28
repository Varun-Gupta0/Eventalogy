import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String paymentId;
  final String eventId;
  final String bookingId;
  final String customerId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String transactionId;
  final String status;
  final Timestamp? paidAt;
  final Timestamp createdAt;

  const PaymentModel({
    required this.paymentId,
    required this.eventId,
    required this.bookingId,
    required this.customerId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.transactionId,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel(
      paymentId: data['paymentId'] as String? ?? doc.id,
      eventId: data['eventId'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      status: data['status'] as String? ?? '',
      paidAt: data['paidAt'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'paymentId': paymentId,
      'eventId': eventId,
      'bookingId': bookingId,
      'customerId': customerId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'status': status,
      if (paidAt != null) 'paidAt': paidAt,
      'createdAt': createdAt,
    };
  }

  PaymentModel copyWith({
    String? paymentId,
    String? eventId,
    String? bookingId,
    String? customerId,
    double? amount,
    String? currency,
    String? paymentMethod,
    String? transactionId,
    String? status,
    Timestamp? paidAt,
    Timestamp? createdAt,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      eventId: eventId ?? this.eventId,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
