import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Forces a fresh ID token so newly-set custom claims (e.g. the `staff`
  /// claim, set by a Cloud Function after this doc/account already existed)
  /// become visible to security rules without requiring a full re-login.
  Future<void> refreshClaims() => _auth.currentUser?.getIdToken(true) ?? Future.value();
}
