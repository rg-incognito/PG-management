import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/broadcast.dart';
import '../models/maintenance_ticket.dart';
import '../models/payment.dart';
import '../models/pg.dart';
import '../models/tenant.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Finds the tenant doc linked to the signed-in user (via `authUid`,
  /// stamped by the provisionTenantLogin Cloud Function when the owner
  /// created this login). Null if not linked to any tenant.
  Future<Tenant?> findTenantByAuthUid(String authUid) async {
    final query = await _db.collection('tenants').where('authUid', isEqualTo: authUid).limit(1).get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return Tenant.fromMap(doc.id, doc.data());
  }

  Future<void> updateFcmToken(String tenantId, String token) {
    return _db.collection('tenants').doc(tenantId).set({'fcmToken': token}, SetOptions(merge: true));
  }

  Stream<Tenant?> watchTenant(String tenantId) {
    return _db.collection('tenants').doc(tenantId).snapshots().map(
          (d) => d.exists ? Tenant.fromMap(d.id, d.data()!) : null,
        );
  }

  /// Appends a newly-uploaded document and puts verification back to
  /// 'pending' for staff to review — allowed whether this is the first
  /// submission or a re-submission after a rejection.
  Future<void> submitDocument(String tenantId, TenantDocument document) {
    return _db.collection('tenants').doc(tenantId).update({
      'documents': FieldValue.arrayUnion([document.toMap()]),
      'verificationStatus': VerificationStatus.pending.name,
    });
  }

  Future<void> updateContactInfo(
    String tenantId, {
    required String mobile,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return _db.collection('tenants').doc(tenantId).update({
      'mobile': mobile,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
    });
  }

  Stream<Pg?> watchPg(String pgId) {
    return _db.collection('pgs').doc(pgId).snapshots().map(
          (d) => d.exists ? Pg.fromMap(d.id, d.data()!) : null,
        );
  }

  Stream<List<Payment>> watchPayments(String tenantId) {
    return _db
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());
  }

  // Announcements are a notice board, not an archive — only show the last
  // 24 hours' worth. Drives both the Announcements list and the unread
  // badge on Home, so an old one stops counting too, not just displaying.
  Stream<List<Broadcast>> watchBroadcasts(String pgId) {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    return _db
        .collection('broadcasts')
        .where('pgId', isEqualTo: pgId)
        .where('sentAt', isGreaterThan: cutoff)
        .orderBy('sentAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => Broadcast.fromMap(d.id, d.data())).toList());
  }

  Future<void> markBroadcastsSeen(String tenantId) {
    return _db.collection('tenants').doc(tenantId).set(
      {'lastSeenBroadcastAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Stream<List<MaintenanceTicket>> watchMyTickets(String tenantAuthUid) {
    return _db
        .collection('maintenanceTickets')
        .where('tenantAuthUid', isEqualTo: tenantAuthUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MaintenanceTicket.fromMap(d.id, d.data())).toList());
  }

  Future<void> createTicket({
    required String pgId,
    required String tenantId,
    required String tenantAuthUid,
    required String tenantName,
    required String title,
    required String description,
    String? photoUrl,
  }) {
    return _db.collection('maintenanceTickets').add({
      'pgId': pgId,
      'tenantId': tenantId,
      'tenantAuthUid': tenantAuthUid,
      'tenantName': tenantName,
      'title': title,
      'description': description,
      'photoUrl': ?photoUrl,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitPaymentClaim({
    required String tenantId,
    required String tenantAuthUid,
    required String pgId,
    required String month,
    required String receiptUrl,
  }) {
    return _db.collection('paymentClaims').add({
      'tenantId': tenantId,
      'tenantAuthUid': tenantAuthUid,
      'pgId': pgId,
      'month': month,
      'receiptUrl': receiptUrl,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
