import 'package:cloud_firestore/cloud_firestore.dart';

enum VerificationStatus { notSubmitted, pending, verified, rejected }

VerificationStatus verificationStatusFromString(String value) => VerificationStatus.values
    .firstWhere((s) => s.name == value, orElse: () => VerificationStatus.notSubmitted);

class TenantDocument {
  final String type;
  final String url;
  final DateTime uploadedAt;

  TenantDocument({required this.type, required this.url, required this.uploadedAt});

  factory TenantDocument.fromMap(Map<String, dynamic> map) => TenantDocument(
        type: map['type'] as String? ?? '',
        url: map['url'] as String? ?? '',
        uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  // Firestore doesn't allow FieldValue.serverTimestamp() inside array
  // elements, so this stamps the time client-side instead.
  Map<String, dynamic> toMap() => {
        'type': type,
        'url': url,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };
}

class Tenant {
  final String id;
  final String name;
  final String mobile;
  final String pgId;
  final double rentAmount;
  final String? authUid;
  final List<TenantDocument> documents;
  final VerificationStatus verificationStatus;
  final String? verificationNote;
  final DateTime? lastSeenBroadcastAt;

  Tenant({
    required this.id,
    required this.name,
    required this.mobile,
    required this.pgId,
    required this.rentAmount,
    this.authUid,
    this.documents = const [],
    this.verificationStatus = VerificationStatus.notSubmitted,
    this.verificationNote,
    this.lastSeenBroadcastAt,
  });

  factory Tenant.fromMap(String id, Map<String, dynamic> map) {
    return Tenant(
      id: id,
      name: map['name'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      pgId: map['pgId'] as String? ?? '',
      rentAmount: (map['rentAmount'] as num?)?.toDouble() ?? 0,
      authUid: map['authUid'] as String?,
      documents: (map['documents'] as List? ?? const [])
          .map((d) => TenantDocument.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList(),
      verificationStatus: verificationStatusFromString(map['verificationStatus'] as String? ?? 'notSubmitted'),
      verificationNote: map['verificationNote'] as String?,
      lastSeenBroadcastAt: (map['lastSeenBroadcastAt'] as Timestamp?)?.toDate(),
    );
  }
}
