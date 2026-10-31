import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around FirebaseAuth and GoogleSignIn.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Explicitly configure GoogleSignIn with Web Client ID from google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '865916319593-evblkerte3nn4jge3ajee91c7r2vfjgu.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  /// The currently signed-in Firebase user, or null when signed-out.
  User? get currentUser => _auth.currentUser;

  /// Stream that emits whenever the auth state changes (sign-in / sign-out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a new Firebase Auth user.
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends password reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs in with Google using Firebase Authentication.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Disconnect previous Google session to force account picker
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled sign-in flow
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      debugPrint('[AuthService] PlatformException during Google Sign-In: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed' || e.toString().contains('10')) {
        throw Exception(
          'Google Sign-In failed (ApiException 10). '
          'Please ensure the SHA-1 fingerprint for your build is added to Firebase Console and Google Sign-In is enabled.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Signs out the current user and disconnects Google session.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _auth.signOut();
  }
}
