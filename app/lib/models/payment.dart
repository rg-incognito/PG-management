import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMode { cash, upi, bank }

PaymentMode paymentModeFromString(String value) =>
    PaymentMode.values.firstWhere((m) => m.name == value, orElse: () => PaymentMode.cash);

enum PaymentStatus { paid, pending, overdue }

PaymentStatus paymentStatusFromString(String value) => PaymentStatus.values
    .firstWhere((s) => s.name == value, orElse: () => PaymentStatus.pending);

class Payment {
  final String id;
  final String tenantId;
  final String pgId;
  final String month; // "YYYY-MM"
  final double amountPaid;
  final PaymentMode mode;
  final String? markedBy;
  final DateTime? markedAt;
  final PaymentStatus status;
  final num penaltyApplied;

  Payment({
    required this.id,
    required this.tenantId,
    required this.pgId,
    required this.month,
    required this.amountPaid,
    required this.mode,
    this.markedBy,
    this.markedAt,
    required this.status,
    this.penaltyApplied = 0,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) {
    return Payment(
      id: id,
      tenantId: map['tenantId'] as String? ?? '',
      pgId: map['pgId'] as String? ?? '',
      month: map['month'] as String? ?? '',
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      mode: paymentModeFromString(map['mode'] as String? ?? 'cash'),
      markedBy: map['markedBy'] as String?,
      markedAt: (map['markedAt'] as Timestamp?)?.toDate(),
      status: paymentStatusFromString(map['status'] as String? ?? 'pending'),
      penaltyApplied: map['penaltyApplied'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tenantId': tenantId,
        'pgId': pgId,
        'month': month,
        'amountPaid': amountPaid,
        'mode': mode.name,
        'markedBy': markedBy,
        'markedAt': FieldValue.serverTimestamp(),
        'status': status.name,
        'penaltyApplied': penaltyApplied,
      };
}
