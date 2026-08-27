import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bed.dart';
import '../models/broadcast.dart';
import '../models/flat.dart';
import '../models/maintenance_ticket.dart';
import '../models/payment.dart';
import '../models/payment_claim.dart';
import '../models/pg.dart';
import '../models/pg_settings.dart';
import '../models/room.dart';
import '../models/room_type.dart';
import '../models/staff.dart';
import '../models/tenant.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Staff ---
  Future<Staff?> getStaff(String uid) async {
    final doc = await _db.collection('staff').doc(uid).get();
    if (!doc.exists) return null;
    return Staff.fromMap(doc.id, doc.data()!);
  }

  Future<void> registerStaffFcmToken(String uid, String token) {
    return _db.collection('staff').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Owner-only per Firestore rules — a manager's `list` on this collection
  /// is denied, so this naturally returns nothing useful for non-owners.
  Stream<List<Staff>> watchAllStaff() {
    return _db.collection('staff').orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => Staff.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> updateStaffAssignment(String staffId, {required String role, required List<String> assignedPgIds}) {
    return _db.collection('staff').doc(staffId).set(
      {'role': role, 'assignedPgIds': assignedPgIds},
      SetOptions(merge: true),
    );
  }

  // --- PGs ---
  Stream<List<Pg>> watchPgs(List<String> pgIds) {
    if (pgIds.isEmpty) return Stream.value(const []);
    return _db
        .collection('pgs')
        .where(FieldPath.documentId, whereIn: pgIds)
        .snapshots()
        .map((s) => s.docs.map((d) => Pg.fromMap(d.id, d.data())).toList());
  }

  /// Creates a PG and immediately grants the creating owner access to it —
  /// otherwise they'd create a PG their own /staff.assignedPgIds doesn't
  /// list, and Firestore rules would hide it from them right away.
  Future<String> createPg({required String name, required String address, required String ownerUid}) async {
    final pgRef = _db.collection('pgs').doc();
    final batch = _db.batch();
    batch.set(pgRef, Pg(id: pgRef.id, name: name, address: address, totalRooms: 0, staffIds: [ownerUid]).toMap());
    batch.update(_db.collection('staff').doc(ownerUid), {
      'assignedPgIds': FieldValue.arrayUnion([pgRef.id]),
    });
    await batch.commit();
    return pgRef.id;
  }

  Future<void> updatePg(String pgId, {required String name, required String address}) {
    return _db.collection('pgs').doc(pgId).set({'name': name, 'address': address}, SetOptions(merge: true));
  }

  Future<void> updatePgQrUrl(String pgId, String qrUrl) {
    return _db.collection('pgs').doc(pgId).set({'paymentQrUrl': qrUrl}, SetOptions(merge: true));
  }

  // --- Room types ---
  Stream<List<RoomType>> watchRoomTypes(String pgId) {
    return _db
        .collection('roomTypes')
        .where('pgId', isEqualTo: pgId)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => RoomType.fromMap(d.id, d.data())).toList());
  }

  Future<void> upsertRoomType(RoomType roomType) {
    final ref =
        roomType.id.isEmpty ? _db.collection('roomTypes').doc() : _db.collection('roomTypes').doc(roomType.id);
    return ref.set(roomType.toMap(), SetOptions(merge: true));
  }

  // --- Flats ---
  Stream<List<Flat>> watchFlats(String pgId) {
    return _db
        .collection('flats')
        .where('pgId', isEqualTo: pgId)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => Flat.fromMap(d.id, d.data())).toList());
  }

  Future<void> upsertFlat(Flat flat) {
    final ref = flat.id.isEmpty ? _db.collection('flats').doc() : _db.collection('flats').doc(flat.id);
    return ref.set(flat.toMap(), SetOptions(merge: true));
  }

  /// Caller must first confirm the flat has no rooms — this doesn't cascade.
  Future<void> deleteFlat(String flatId) {
    return _db.collection('flats').doc(flatId).delete();
  }

  // --- Rooms ---
  Stream<List<Room>> watchRooms(String pgId) {
    return _db
        .collection('rooms')
        .where('pgId', isEqualTo: pgId)
        .orderBy('roomNumber')
        .snapshots()
        .map((s) => s.docs.map((d) => Room.fromMap(d.id, d.data())).toList());
  }

  Future<Room?> getRoom(String roomId) async {
    final doc = await _db.collection('rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return Room.fromMap(doc.id, doc.data()!);
  }

  /// Renames an existing room. Room type / capacity aren't editable here —
  /// changing them would leave the bed count out of sync; delete and
  /// recreate the room instead if the sharing config genuinely changes.
  Future<void> renameRoom(String roomId, String roomNumber) {
    return _db.collection('rooms').doc(roomId).update({'roomNumber': roomNumber});
  }

  /// Deletes a room along with its bed docs. Caller must first confirm none
  /// of the room's beds are occupied.
  Future<void> deleteRoom(String roomId) async {
    final bedsSnap = await _db.collection('beds').where('roomId', isEqualTo: roomId).get();
    final batch = _db.batch();
    for (final doc in bedsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('rooms').doc(roomId));
    await batch.commit();
  }

  /// Creates a room under [flatId] with [roomType]'s capacity, and
  /// generates one Bed doc per capacity slot in the same batch — beds are
  /// always kept in sync with the room's capacity this way, no separate
  /// counter to drift out of sync.
  Future<void> createRoom({
    required String pgId,
    required String flatId,
    required String roomNumber,
    required RoomType roomType,
  }) async {
    final roomRef = _db.collection('rooms').doc();
    final room = Room(
      id: roomRef.id,
      pgId: pgId,
      flatId: flatId,
      roomTypeId: roomType.id,
      roomNumber: roomNumber,
      capacity: roomType.capacity,
    );
    final batch = _db.batch();
    batch.set(roomRef, room.toMap());
    for (var i = 1; i <= roomType.capacity; i++) {
      final bedRef = _db.collection('beds').doc();
      final bed = Bed(id: bedRef.id, pgId: pgId, flatId: flatId, roomId: roomRef.id, bedLabel: 'Bed $i');
      batch.set(bedRef, bed.toMap());
    }
    await batch.commit();
  }

  // --- Beds ---
  Stream<List<Bed>> watchBeds(String pgId) {
    return _db
        .collection('beds')
        .where('pgId', isEqualTo: pgId)
        .orderBy('bedLabel')
        .snapshots()
        .map((s) => s.docs.map((d) => Bed.fromMap(d.id, d.data())).toList());
  }

  Future<Bed?> getBed(String bedId) async {
    final doc = await _db.collection('beds').doc(bedId).get();
    if (!doc.exists) return null;
    return Bed.fromMap(doc.id, doc.data()!);
  }

  /// Moves a tenant onto [newBedId] (nullable — e.g. tenant exiting with no
  /// replacement bed) and frees [oldBedId] if given. Atomic batch so a bed
  /// is never left double-booked or a tenant left without a assigned bed.
  Future<void> changeTenantBed({String? oldBedId, String? newBedId, required String tenantId}) async {
    final batch = _db.batch();
    if (oldBedId != null && oldBedId.isNotEmpty) {
      batch.update(_db.collection('beds').doc(oldBedId), {'tenantId': null});
    }
    if (newBedId != null && newBedId.isNotEmpty) {
      batch.update(_db.collection('beds').doc(newBedId), {'tenantId': tenantId});
    }
    await batch.commit();
  }

  // --- Tenants ---
  Stream<List<Tenant>> watchTenants(String pgId, {TenantStatus? status}) {
    Query<Map<String, dynamic>> query = _db.collection('tenants').where('pgId', isEqualTo: pgId);
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    return query.orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Tenant?> getTenant(String tenantId) async {
    final doc = await _db.collection('tenants').doc(tenantId).get();
    if (!doc.exists) return null;
    return Tenant.fromMap(doc.id, doc.data()!);
  }

  Future<String> upsertTenant(Tenant tenant) async {
    if (tenant.id.isEmpty) {
      final ref = await _db.collection('tenants').add(tenant.toMap());
      return ref.id;
    }
    await _db.collection('tenants').doc(tenant.id).set(tenant.toMap(), SetOptions(merge: true));
    return tenant.id;
  }

  Stream<List<Tenant>> watchPendingVerifications(String pgId) {
    return _db
        .collection('tenants')
        .where('pgId', isEqualTo: pgId)
        .where('verificationStatus', isEqualTo: VerificationStatus.pending.name)
        .snapshots()
        .map((s) => s.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList());
  }

  Future<void> setVerificationStatus(String tenantId, VerificationStatus status, {String? note}) {
    return _db.collection('tenants').doc(tenantId).update({
      'verificationStatus': status.name,
      'verificationNote': note,
    });
  }

  /// Checks a tenant out: frees their bed and marks them exited with a
  /// deposit-settlement record, in one atomic batch.
  Future<void> exitTenant({
    required String tenantId,
    required String bedId,
    required DateTime exitDate,
    required double depositRefunded,
    String? notes,
  }) async {
    final batch = _db.batch();
    if (bedId.isNotEmpty) {
      batch.update(_db.collection('beds').doc(bedId), {'tenantId': null});
    }
    batch.update(_db.collection('tenants').doc(tenantId), {
      'status': TenantStatus.exited.name,
      'exitDate': Timestamp.fromDate(exitDate),
      'depositRefunded': depositRefunded,
      'exitNotes': notes,
    });
    await batch.commit();
  }

  // --- Payments ---
  Stream<List<Payment>> watchPaymentsForTenant(String tenantId) {
    return _db
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Payment>> watchPaymentsForPgAndMonth(String pgId, String month) {
    return _db
        .collection('payments')
        .where('pgId', isEqualTo: pgId)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((s) => s.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());
  }

  /// Marks a tenant's rent as paid for [month]. Uses a deterministic doc id
  /// (`tenantId_month`) so the daily penalty job and this write target the
  /// same record instead of creating duplicates.
  Future<void> markPaid({
    required String tenantId,
    required String pgId,
    required String month,
    required double amountPaid,
    required PaymentMode mode,
    required String markedByUid,
    String? receiptUrl,
  }) {
    final payment = Payment(
      id: '${tenantId}_$month',
      tenantId: tenantId,
      pgId: pgId,
      month: month,
      amountPaid: amountPaid,
      mode: mode,
      markedBy: markedByUid,
      status: PaymentStatus.paid,
      receiptUrl: receiptUrl,
    );
    return _db.collection('payments').doc(payment.id).set(payment.toMap(), SetOptions(merge: true));
  }

  /// Recent payment-marking activity for the activity log, newest first.
  /// Docs without `markedAt` (never marked paid) are naturally excluded by
  /// the orderBy.
  Stream<List<Payment>> watchRecentPayments(String pgId, {int limit = 50}) {
    return _db
        .collection('payments')
        .where('pgId', isEqualTo: pgId)
        .orderBy('markedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());
  }

  // --- Payment claims ---
  Stream<List<PaymentClaim>> watchPendingClaims(String pgId) {
    return _db
        .collection('paymentClaims')
        .where('pgId', isEqualTo: pgId)
        .where('status', isEqualTo: PaymentClaimStatus.pending.name)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PaymentClaim.fromMap(d.id, d.data())).toList());
  }

  /// Recently reviewed (approved/rejected) claims for the activity log,
  /// newest first. Still-pending claims lack `reviewedAt` and are naturally
  /// excluded by the orderBy.
  Stream<List<PaymentClaim>> watchRecentResolvedClaims(String pgId, {int limit = 50}) {
    return _db
        .collection('paymentClaims')
        .where('pgId', isEqualTo: pgId)
        .orderBy('reviewedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => PaymentClaim.fromMap(d.id, d.data())).toList());
  }

  /// Approves a claim: marks the underlying payment paid and flips the
  /// claim to approved. Rejects instead if [approve] is false.
  Future<void> resolveClaim({
    required PaymentClaim claim,
    required bool approve,
    required String reviewerUid,
    double? amountPaid,
    PaymentMode mode = PaymentMode.upi,
  }) async {
    if (approve) {
      await markPaid(
        tenantId: claim.tenantId,
        pgId: claim.pgId,
        month: claim.month,
        amountPaid: amountPaid ?? 0,
        mode: mode,
        markedByUid: reviewerUid,
        receiptUrl: claim.receiptUrl,
      );
    }
    await _db.collection('paymentClaims').doc(claim.id).update({
      'status': approve ? PaymentClaimStatus.approved.name : PaymentClaimStatus.rejected.name,
      'reviewedBy': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Settings ---
  Future<PgSettings> getSettings(String pgId) async {
    final doc = await _db.collection('settings').doc(pgId).get();
    if (!doc.exists) return PgSettings(pgId: pgId);
    return PgSettings.fromMap(pgId, doc.data()!);
  }

  Future<void> saveSettings(PgSettings settings) {
    return _db.collection('settings').doc(settings.pgId).set(settings.toMap(), SetOptions(merge: true));
  }

  // --- Broadcasts ---
  Stream<List<Broadcast>> watchBroadcasts(String pgId) {
    return _db
        .collection('broadcasts')
        .where('pgId', isEqualTo: pgId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Broadcast.fromMap(d.id, d.data())).toList());
  }

  Future<void> sendBroadcast({required String pgId, required String title, required String message, required String sentByUid}) {
    final broadcast = Broadcast(id: '', pgId: pgId, title: title, message: message, sentBy: sentByUid);
    return _db.collection('broadcasts').add(broadcast.toMap());
  }

  // --- Maintenance tickets ---
  Stream<List<MaintenanceTicket>> watchTickets(String pgId) {
    return _db
        .collection('maintenanceTickets')
        .where('pgId', isEqualTo: pgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MaintenanceTicket.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
    String? resolutionNote,
    String? resolvedByUid,
  }) {
    return _db.collection('maintenanceTickets').doc(ticketId).update({
      'status': status.name,
      if (status == TicketStatus.resolved) 'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': ?resolvedByUid,
      'resolutionNote': ?resolutionNote,
    });
  }
}
