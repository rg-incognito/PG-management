import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    // Refresh once, right after sign-in, so a `tenantId` custom claim set
    // after this login was created (or reset) is picked up. Done here —
    // once, synchronously in the sign-in flow — rather than reactively
    // inside a provider, since repeated/concurrent forced token refreshes
    // triggered by Riverpod rebuilds appeared to desync the native Storage
    // SDK's cached auth state on at least one device.
    await credential.user?.getIdToken(true);
    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendEmailVerification() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return user.sendEmailVerification();
  }

  /// Reloads the current user from Firebase and returns whether their email
  /// is now verified. `emailVerified` on the cached User doesn't update on
  /// its own after the user clicks the verification link, so this must be
  /// called explicitly (e.g. when the user taps "I've verified").
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
