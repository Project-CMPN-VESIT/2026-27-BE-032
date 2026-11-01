import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Manages authentication state and exposes it to the widget tree via Provider.
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isPerformingAuthAction = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    debugPrint('[AuthProvider] Initializing – listening to authStateChanges');
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // ─── Auth State Listener ──────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_isPerformingAuthAction) {
      debugPrint('[AuthProvider._onAuthStateChanged] SUPPRESSED during active auth action');
      return;
    }

    debugPrint('[AuthProvider._onAuthStateChanged] FIRE -> uid=${firebaseUser?.uid}');

    if (firebaseUser == null) {
      _user = null;
      notifyListeners();
      return;
    }

    try {
      final firestoreUser = await _firestoreService.getUser(firebaseUser.uid);
      _user = firestoreUser ??
          UserModel(
            uid: firebaseUser.uid,
            fullName: firebaseUser.displayName ?? 'User',
            email: firebaseUser.email ?? '',
          );
    } catch (e, st) {
      debugPrint('[AuthProvider._onAuthStateChanged] Firestore read error: $e');
      debugPrint(st.toString());
      _user = UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? '',
      );
    }

    notifyListeners();
  }

  // ─── Login Method ─────────────────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    debugPrint('[AuthProvider] login() START → email=$email');
    _setLoading(true);
    _isPerformingAuthAction = true;

    try {
      final credential = await _authService.signInWithEmail(email, password);
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return 'Sign in failed. Could not retrieve user account.';
      }

      final uid = firebaseUser.uid;

      UserModel? firestoreUser;
      try {
        firestoreUser = await _firestoreService.getUser(uid);
      } catch (e, st) {
        debugPrint('[AuthProvider] login() Firestore getUser failed: $e');
        debugPrint(st.toString());
      }

      if (firestoreUser != null) {
        _user = firestoreUser;
      } else {
        try {
          await _firestoreService.createUser(
            uid: uid,
            fullName: firebaseUser.displayName ?? 'User',
            email: email.trim(),
          );
        } catch (e, st) {
          debugPrint('[AuthProvider] login() Auto-create doc failed: $e');
          debugPrint(st.toString());
        }

        _user = UserModel(
          uid: uid,
          fullName: firebaseUser.displayName ?? 'User',
          email: email.trim(),
        );
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AuthProvider] login() FirebaseAuthException: code=${e.code}');
      debugPrint(st.toString());
      return _mapAuthError(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AuthProvider] login() FirebaseException: code=${e.code}');
      debugPrint(st.toString());
      return e.message ?? 'Firebase error occurred during login.';
    } catch (e, st) {
      debugPrint('[AuthProvider] login() UNEXPECTED ERROR: $e');
      debugPrint(st.toString());
      return e.toString();
    } finally {
      _isPerformingAuthAction = false;
      _setLoading(false);
    }
  }

  // ─── Register Method (No Phone Field) ────────────────────────────────────

  Future<String?> register(
    String fullName,
    String email,
    String password,
  ) async {
    debugPrint('[AuthProvider] register() START → email=$email, name=$fullName');
    _setLoading(true);
    _isPerformingAuthAction = true;

    try {
      final credential = await _authService.registerWithEmail(email, password);
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        return 'Registration failed. Could not create user account.';
      }

      final uid = firebaseUser.uid;

      await _firestoreService.createUser(
        uid: uid,
        fullName: fullName.trim(),
        email: email.trim(),
      );

      _user = UserModel(
        uid: uid,
        fullName: fullName.trim(),
        email: email.trim(),
      );

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AuthProvider] register() FirebaseAuthException: code=${e.code}');
      debugPrint(st.toString());
      return _mapAuthError(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AuthProvider] register() FirebaseException: code=${e.code}');
      debugPrint(st.toString());
      return e.message ?? 'Firebase error occurred during registration.';
    } catch (e, st) {
      debugPrint('[AuthProvider] register() UNEXPECTED ERROR: $e');
      debugPrint(st.toString());
      return e.toString();
    } finally {
      _isPerformingAuthAction = false;
      _setLoading(false);
    }
  }

  // ─── Google Sign-In Method ───────────────────────────────────────────────

  Future<String?> signInWithGoogle() async {
    debugPrint('[AuthProvider] signInWithGoogle() START');
    _setLoading(true);
    _isPerformingAuthAction = true;

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User cancelled the Google sign-in dialog
        return 'Google Sign-In cancelled.';
      }

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return 'Google Sign-In failed to retrieve user credentials.';
      }

      final uid = firebaseUser.uid;
      final name = firebaseUser.displayName ?? 'Google User';
      final email = firebaseUser.email ?? '';
      final photoUrl = firebaseUser.photoURL;

      UserModel? firestoreUser;
      try {
        firestoreUser = await _firestoreService.getUser(uid);
      } catch (e, st) {
        debugPrint('[AuthProvider] Google Sign-In getUser failed: $e');
        debugPrint(st.toString());
      }

      if (firestoreUser != null) {
        _user = firestoreUser;
      } else {
        try {
          await _firestoreService.createUser(
            uid: uid,
            fullName: name,
            email: email,
          );
          if (photoUrl != null) {
            await _firestoreService.updateUser(uid, {'photoUrl': photoUrl});
          }
        } catch (e, st) {
          debugPrint('[AuthProvider] Google Sign-In createUser failed: $e');
          debugPrint(st.toString());
        }

        _user = UserModel(
          uid: uid,
          fullName: name,
          email: email,
          photoUrl: photoUrl,
        );
      }

      notifyListeners();
      return null; // Success!
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AuthProvider] Google Sign-In FirebaseAuthException: code=${e.code}');
      debugPrint(st.toString());
      return _mapAuthError(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AuthProvider] Google Sign-In FirebaseException: code=${e.code}');
      debugPrint(st.toString());
      return e.message ?? 'Firebase error occurred during Google sign-in.';
    } catch (e, st) {
      debugPrint('[AuthProvider] Google Sign-In UNEXPECTED ERROR: $e');
      debugPrint(st.toString());
      return e.toString();
    } finally {
      _isPerformingAuthAction = false;
      _setLoading(false);
    }
  }

  // ─── Forgot Password Method ───────────────────────────────────────────────

  Future<String?> sendPasswordResetEmail(String email) async {
    debugPrint('[AuthProvider] sendPasswordResetEmail() → email=$email');
    if (email.trim().isEmpty) {
      return 'Please enter your email address.';
    }

    try {
      await _authService.sendPasswordResetEmail(email.trim());
      return null; // Success!
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[AuthProvider] sendPasswordResetEmail FirebaseAuthException: code=${e.code}');
      debugPrint(st.toString());
      return _mapAuthError(e);
    } on FirebaseException catch (e, st) {
      debugPrint('[AuthProvider] sendPasswordResetEmail FirebaseException: code=${e.code}');
      debugPrint(st.toString());
      return e.message ?? 'Failed to send password reset email.';
    } catch (e, st) {
      debugPrint('[AuthProvider] sendPasswordResetEmail UNEXPECTED ERROR: $e');
      debugPrint(st.toString());
      return e.toString();
    }
  }

  // ─── Logout Method ────────────────────────────────────────────────────────

  Future<void> logout() async {
    debugPrint('[AuthProvider] logout()');
    _user = null;
    notifyListeners();
    await _authService.signOut();
  }

  // ─── Update Profile Method ────────────────────────────────────────────────

  Future<String?> updateProfile({String? fullName, String? photoUrl}) async {
    if (_user == null) return 'Not authenticated.';
    debugPrint('[AuthProvider] updateProfile() uid=${_user!.uid}');

    final updateData = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      updateData['fullName'] = fullName.trim();
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      updateData['photoUrl'] = photoUrl.trim();
    }

    if (updateData.isEmpty) return null;

    try {
      await _firestoreService.updateUser(_user!.uid, updateData);
      final updated = await _firestoreService.getUser(_user!.uid);
      if (updated != null) {
        _user = updated;
      } else {
        _user = UserModel(
          uid: _user!.uid,
          fullName: fullName ?? _user!.fullName,
          email: _user!.email,
          phone: _user!.phone,
          photoUrl: photoUrl ?? _user!.photoUrl,
          createdAt: _user!.createdAt,
        );
      }
      notifyListeners();
      return null; // Success
    } on FirebaseException catch (e, st) {
      debugPrint('[AuthProvider] updateProfile FirebaseException: code=${e.code}');
      debugPrint(st.toString());
      return e.message ?? 'Profile update failed.';
    } catch (e, st) {
      debugPrint('[AuthProvider] updateProfile UNEXPECTED ERROR: $e');
      debugPrint(st.toString());
      return e.toString();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid credentials. Please check your email and password.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before retrying.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Sign-in method is not enabled in Firebase Console.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      default:
        return e.message ?? 'Authentication failed [${e.code}].';
    }
  }
}
