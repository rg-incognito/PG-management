import 'package:cloud_firestore/cloud_firestore.dart';

class Broadcast {
  final String id;
  final String title;
  final String message;
  final DateTime? sentAt;

  Broadcast({required this.id, required this.title, required this.message, this.sentAt});

  factory Broadcast.fromMap(String id, Map<String, dynamic> map) {
    return Broadcast(
      id: id,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
