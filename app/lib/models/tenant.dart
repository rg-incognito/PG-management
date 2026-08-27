import 'package:cloud_firestore/cloud_firestore.dart';

enum TenantStatus { active, exited }

TenantStatus tenantStatusFromString(String value) => TenantStatus.values
    .firstWhere((s) => s.name == value, orElse: () => TenantStatus.active);

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
  final String email;
  final String? photoUrl;
  final String pgId;
  final String bedId;
  final double rentAmount;
  final double depositAmount;
  final DateTime? joinDate;
  final TenantStatus status;
  final List<TenantDocument> documents;
  final VerificationStatus verificationStatus;
  final String? verificationNote;
  final String? fcmToken;
  final String? authUid;
  final DateTime? exitDate;
  final double? depositRefunded;
  final String? exitNotes;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  Tenant({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    this.photoUrl,
    required this.pgId,
    required this.bedId,
    required this.rentAmount,
    required this.depositAmount,
    this.joinDate,
    required this.status,
    this.documents = const [],
    this.verificationStatus = VerificationStatus.notSubmitted,
    this.verificationNote,
    this.fcmToken,
    this.authUid,
    this.exitDate,
    this.depositRefunded,
    this.exitNotes,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory Tenant.fromMap(String id, Map<String, dynamic> map) {
    return Tenant(
      id: id,
      name: map['name'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      pgId: map['pgId'] as String? ?? '',
      bedId: map['bedId'] as String? ?? '',
      rentAmount: (map['rentAmount'] as num?)?.toDouble() ?? 0,
      depositAmount: (map['depositAmount'] as num?)?.toDouble() ?? 0,
      joinDate: (map['joinDate'] as Timestamp?)?.toDate(),
      status: tenantStatusFromString(map['status'] as String? ?? 'active'),
      documents: (map['documents'] as List? ?? const [])
          .map((d) => TenantDocument.fromMap(Map<String, dynamic>.from(d as Map)))
          .toList(),
      verificationStatus: verificationStatusFromString(map['verificationStatus'] as String? ?? 'notSubmitted'),
      verificationNote: map['verificationNote'] as String?,
      fcmToken: map['fcmToken'] as String?,
      authUid: map['authUid'] as String?,
      exitDate: (map['exitDate'] as Timestamp?)?.toDate(),
      depositRefunded: (map['depositRefunded'] as num?)?.toDouble(),
      exitNotes: map['exitNotes'] as String?,
      emergencyContactName: map['emergencyContactName'] as String?,
      emergencyContactPhone: map['emergencyContactPhone'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'mobile': mobile,
        'email': email,
        'photoUrl': photoUrl,
        'pgId': pgId,
        'bedId': bedId,
        'rentAmount': rentAmount,
        'depositAmount': depositAmount,
        'joinDate': joinDate != null ? Timestamp.fromDate(joinDate!) : FieldValue.serverTimestamp(),
        'status': status.name,
        'documents': documents.map((d) => d.toMap()).toList(),
        'verificationStatus': verificationStatus.name,
        if (verificationNote != null) 'verificationNote': verificationNote,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (authUid != null) 'authUid': authUid,
        if (exitDate != null) 'exitDate': Timestamp.fromDate(exitDate!),
        if (depositRefunded != null) 'depositRefunded': depositRefunded,
        if (exitNotes != null) 'exitNotes': exitNotes,
        if (emergencyContactName != null) 'emergencyContactName': emergencyContactName,
        if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
      };
}
