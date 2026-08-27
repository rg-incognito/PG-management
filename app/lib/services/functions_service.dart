import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Creates (or resets) the tenant's email/password login and returns the
  /// generated password — Firebase never lets us read it back afterwards,
  /// so the caller must show/copy it immediately.
  Future<({String email, String password})> provisionTenantLogin(String tenantId) async {
    final result = await _functions.httpsCallable('provisionTenantLogin').call({'tenantId': tenantId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return (email: data['email'] as String, password: data['password'] as String);
  }

  /// Creates (or resets) a staff member's email/password login, and writes
  /// their /staff doc (name, role, assignedPgIds). Owner-only server-side.
  Future<({String email, String password})> provisionStaffLogin({
    required String email,
    required String name,
    required String role,
    required List<String> assignedPgIds,
  }) async {
    final result = await _functions.httpsCallable('provisionStaffLogin').call({
      'email': email,
      'name': name,
      'role': role,
      'assignedPgIds': assignedPgIds,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (email: data['email'] as String, password: data['password'] as String);
  }

  /// Pushes a rent reminder right now to every active tenant in [pgId] who
  /// hasn't paid the current month. Returns how many were notified.
  Future<int> sendPendingReminders(String pgId) async {
    final result = await _functions.httpsCallable('sendPendingReminders').call({'pgId': pgId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['notified'] as int;
  }
}
