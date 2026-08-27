import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/broadcast.dart';
import '../models/maintenance_ticket.dart';
import '../models/payment.dart';
import '../models/pg.dart';
import '../models/tenant.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'messaging_service.dart';
import 'storage_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());
final storageServiceProvider = Provider((ref) => StorageService());
final messagingServiceProvider = Provider((ref) => MessagingService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Looks up the tenant doc linked to the signed-in user and registers this
/// device's FCM token onto it. Null if this login isn't linked to a tenant.
final linkedTenantProvider = FutureProvider<Tenant?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final tenant = await ref.watch(firestoreServiceProvider).findTenantByAuthUid(user.uid);
  if (tenant == null) return null;

  final token = await ref.watch(messagingServiceProvider).getToken();
  if (token != null) {
    await ref.watch(firestoreServiceProvider).updateFcmToken(tenant.id, token);
  }
  return tenant;
});

final paymentsProvider = StreamProvider.family<List<Payment>, String>((ref, tenantId) {
  return ref.watch(firestoreServiceProvider).watchPayments(tenantId);
});

final pgProvider = StreamProvider.family<Pg?, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchPg(pgId);
});

/// Live view of a tenant doc (for reflecting verification status/documents
/// updates in real time, unlike the one-shot linkedTenantProvider lookup).
final tenantStreamProvider = StreamProvider.family<Tenant?, String>((ref, tenantId) {
  return ref.watch(firestoreServiceProvider).watchTenant(tenantId);
});

final broadcastsProvider = StreamProvider.family<List<Broadcast>, String>((ref, pgId) {
  return ref.watch(firestoreServiceProvider).watchBroadcasts(pgId);
});

final myTicketsProvider = StreamProvider.family<List<MaintenanceTicket>, String>((ref, tenantAuthUid) {
  return ref.watch(firestoreServiceProvider).watchMyTickets(tenantAuthUid);
});
