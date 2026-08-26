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
}
