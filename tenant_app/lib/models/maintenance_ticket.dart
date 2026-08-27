import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketStatus { open, inProgress, resolved }

TicketStatus ticketStatusFromString(String value) =>
    TicketStatus.values.firstWhere((s) => s.name == value, orElse: () => TicketStatus.open);

class MaintenanceTicket {
  final String id;
  final String title;
  final String description;
  final String? photoUrl;
  final TicketStatus status;
  final DateTime? createdAt;
  final String? resolutionNote;

  MaintenanceTicket({
    required this.id,
    required this.title,
    required this.description,
    this.photoUrl,
    required this.status,
    this.createdAt,
    this.resolutionNote,
  });

  factory MaintenanceTicket.fromMap(String id, Map<String, dynamic> map) {
    return MaintenanceTicket(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      status: ticketStatusFromString(map['status'] as String? ?? 'open'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      resolutionNote: map['resolutionNote'] as String?,
    );
  }
}
