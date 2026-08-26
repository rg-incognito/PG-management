import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentClaimStatus { pending, approved, rejected }

PaymentClaimStatus paymentClaimStatusFromString(String value) => PaymentClaimStatus.values
    .firstWhere((s) => s.name == value, orElse: () => PaymentClaimStatus.pending);

class PaymentClaim {
  final String id;
  final String tenantId;
  final String tenantAuthUid;
  final String pgId;
  final String month;
  final String receiptUrl;
  final DateTime? submittedAt;
  final PaymentClaimStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  PaymentClaim({
    required this.id,
    required this.tenantId,
    required this.tenantAuthUid,
    required this.pgId,
    required this.month,
    required this.receiptUrl,
    this.submittedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory PaymentClaim.fromMap(String id, Map<String, dynamic> map) {
    return PaymentClaim(
      id: id,
      tenantId: map['tenantId'] as String? ?? '',
      tenantAuthUid: map['tenantAuthUid'] as String? ?? '',
      pgId: map['pgId'] as String? ?? '',
      month: map['month'] as String? ?? '',
      receiptUrl: map['receiptUrl'] as String? ?? '',
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      status: paymentClaimStatusFromString(map['status'] as String? ?? 'pending'),
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tenantId': tenantId,
        'tenantAuthUid': tenantAuthUid,
        'pgId': pgId,
        'month': month,
        'receiptUrl': receiptUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': status.name,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': FieldValue.serverTimestamp(),
      };
}
