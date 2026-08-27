class ReceiptData {
  final String receiptNumber;
  final String pgName;
  final String pgAddress;
  final String tenantName;
  final String roomLabel;
  final double amount;
  final double penaltyApplied;
  final String monthLabel; // e.g. "August 2026"
  final String paymentMode;
  final DateTime paidDate;
  final String? ownerName;
  final String? ownerPhone;

  ReceiptData({
    required this.receiptNumber,
    required this.pgName,
    required this.pgAddress,
    required this.tenantName,
    required this.roomLabel,
    required this.amount,
    required this.penaltyApplied,
    required this.monthLabel,
    required this.paymentMode,
    required this.paidDate,
    this.ownerName,
    this.ownerPhone,
  });

  double get total => amount + penaltyApplied;
}
