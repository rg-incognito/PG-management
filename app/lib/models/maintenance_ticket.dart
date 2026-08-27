import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus { open, inProgress, resolved }

TicketStatus ticketStatusFromString(String value) =>
    TicketStatus.values.firstWhere((s) => s.name == value, orElse: () => TicketStatus.open);

class MaintenanceTicket {
  final String id;
  final String pgId;
  final String tenantId;
  final String tenantAuthUid;
  final String tenantName;
  final String title;
  final String description;
  final String? photoUrl;
  final TicketStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;

  MaintenanceTicket({
    required this.id,
    required this.pgId,
    required this.tenantId,
    required this.tenantAuthUid,
    required this.tenantName,
    required this.title,
    required this.description,
    this.photoUrl,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
  });

  factory MaintenanceTicket.fromMap(String id, Map<String, dynamic> map) {
    return MaintenanceTicket(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      tenantAuthUid: map['tenantAuthUid'] as String? ?? '',
      tenantName: map['tenantName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      status: ticketStatusFromString(map['status'] as String? ?? 'open'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: map['resolvedBy'] as String?,
      resolutionNote: map['resolutionNote'] as String?,
    );
  }
}
