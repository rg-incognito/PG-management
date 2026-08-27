import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { paid, pending, overdue }

PaymentStatus paymentStatusFromString(String value) => PaymentStatus.values
    .firstWhere((s) => s.name == value, orElse: () => PaymentStatus.pending);

class Payment {
  final String id;
  final String month; // "YYYY-MM"
  final double amountPaid;
  final PaymentStatus status;
  final num penaltyApplied;
  final String? mode;
  final DateTime? markedAt;
  final String? receiptUrl;

  Payment({
    required this.id,
    required this.month,
    required this.amountPaid,
    required this.status,
    this.penaltyApplied = 0,
    this.mode,
    this.markedAt,
    this.receiptUrl,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      month: map['month'] as String? ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      status: paymentStatusFromString(map['status'] as String? ?? 'pending'),
      penaltyApplied: map['penaltyApplied'] as num? ?? 0,
      mode: map['mode'] as String?,
      markedAt: (map['markedAt'] as Timestamp?)?.toDate(),
      receiptUrl: map['receiptUrl'] as String?,
    );
  }
}
