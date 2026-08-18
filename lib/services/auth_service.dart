import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() {
    final provider = GoogleAuthProvider();
    return kIsWeb
        ? _firebaseAuth.signInWithPopup(provider)
        : _firebaseAuth.signInWithProvider(provider);
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
