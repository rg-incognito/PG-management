import 'package:cloud_firestore/cloud_firestore.dart';

class Broadcast {
  final String id;
  final String pgId;
  final String title;
  final String message;
  final String sentBy;
  final DateTime? sentAt;

  Broadcast({
    required this.id,
    required this.pgId,
    required this.title,
    required this.message,
    required this.sentBy,
    this.sentAt,
  });

  factory Broadcast.fromMap(String id, Map<String, dynamic> map) {
    return Broadcast(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      sentBy: map['sentBy'] as String? ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'pgId': pgId,
        'title': title,
        'message': message,
        'sentBy': sentBy,
        'sentAt': FieldValue.serverTimestamp(),
      };
}
