import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/bed.dart';
import '../models/flat.dart';
import '../models/payment_claim.dart';
import '../models/pg.dart';
import '../models/room.dart';
import '../models/room_type.dart';
import '../models/staff.dart';
import '../models/tenant.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'functions_service.dart';
import 'messaging_service.dart';
import 'storage_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());
final messagingServiceProvider = Provider((ref) => MessagingService());
final storageServiceProvider = Provider((ref) => StorageService());
final functionsServiceProvider = Provider((ref) => FunctionsService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// The signed-in staff member's profile (role + assigned PGs), loaded once
/// auth resolves. Null while signed out or if no /staff doc exists yet.
final currentStaffProvider = FutureProvider<Staff?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(firestoreServiceProvider).getStaff(user.uid);
});

final assignedPgsProvider = StreamProvider<List<Pg>>((ref) {
  final staff = ref.watch(currentStaffProvider).value;
  if (staff == null) return Stream.value(const []);
  return ref.watch(firestoreServiceProvider).watchPgs(staff.assignedPgIds);
});

/// The PG currently selected in the dashboard/tenant screens.
final selectedPgIdProvider = StateProvider<String?>((ref) => null);

final tenantsProvider = StreamProvider.family<List<Tenant>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchTenants(pgId, status: TenantStatus.active);
});

final pendingClaimsProvider = StreamProvider.family<List<PaymentClaim>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchPendingClaims(pgId);
});

final pendingVerificationsProvider = StreamProvider.family<List<Tenant>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchPendingVerifications(pgId);
});

final roomTypesProvider = StreamProvider.family<List<RoomType>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchRoomTypes(pgId);
});

final roomsProvider = StreamProvider.family<List<Room>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchRooms(pgId);
});

final flatsProvider = StreamProvider.family<List<Flat>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchFlats(pgId);
});

final bedsProvider = StreamProvider.family<List<Bed>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchBeds(pgId);
});

/// Forces a fresh ID token once per sign-in so a `staff` custom claim set
/// after this session started (e.g. right after the owner's account was
/// bootstrapped) becomes visible to Storage rules without a full re-login.
final claimsRefreshProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;
  await ref.watch(authServiceProvider).refreshClaims();
});

/// Fetches this device's FCM token and saves it onto the signed-in staff
/// doc once, so payment-claim notifications reach this device. A no-op
/// while signed out.
final fcmTokenRegistrationProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;
  final token = await ref.watch(messagingServiceProvider).getToken();
  if (token == null) return;
  await ref.watch(firestoreServiceProvider).registerStaffFcmToken(user.uid, token);
});
