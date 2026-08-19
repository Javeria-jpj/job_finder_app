import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown by [AuthService] with a message that is safe to show to the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around [FirebaseAuth] so the UI never deals with Firebase
/// error codes directly.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _injectedAuth = auth;

  final FirebaseAuth? _injectedAuth;

  /// Resolved lazily so screens can be constructed (in tests, for example)
  /// without a live Firebase app.
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  /// Emits the signed-in user, or null when signed out. Drives the auth gate.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Creates the account and then signs out, so the user logs in explicitly.
  ///
  /// Firebase signs a new user in as a side effect of creating them; that is
  /// suppressed here on purpose.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;

      // The account now exists. Profile polish and the verification email are
      // best-effort: failing here must not be reported as a failed sign-up,
      // or the user sees an error for an account that was created.
      try {
        await user.updateDisplayName(fullName.trim());
        await user.sendEmailVerification();
        // The cached user still holds the old (empty) display name.
        await user.reload();
      } catch (error) {
        debugPrint('Post-sign-up step failed (account was created): $error');
      }

      // Hand control back to the sign-in screen rather than dropping the new
      // user straight into the app.
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Signs in with Google.
  ///
  /// Returns false when the user closes the popup or cancels — that is not a
  /// failure, so the UI should stay put without showing an error.
  Future<bool> signInWithGoogle() async {
    if (kIsWeb) return _signInWithGooglePopup();
    return _signInWithGoogleNatively();
  }

  /// Browser popup, which already shows the account chooser.
  Future<bool> _signInWithGooglePopup() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      // Always offer the account chooser rather than silently reusing the
      // last Google session.
      ..setCustomParameters({'prompt': 'select_account'});

    try {
      await _auth.signInWithPopup(provider);
      return true;
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) return false;
      throw AuthFailure(_messageFor(e));
    }
  }

  /// The device's own account picker.
  ///
  /// Firebase's [User.signInWithProvider] opens a browser tab where the user
  /// retypes their password and clears 2-Step Verification. Credential
  /// Manager instead lists the accounts already on the phone, so choosing the
  /// email is the whole flow.
  Future<bool> _signInWithGoogleNatively() async {
    try {
      await _ensureGoogleInitialized();

      final google = GoogleSignIn.instance;
      if (!google.supportsAuthenticate()) {
        // Desktop has no native picker; fall back to the browser flow.
        await _auth.signInWithProvider(GoogleAuthProvider());
        return true;
      }

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Google did not return a sign-in token. Try again.',
        );
      }

      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthFailure(_googleMessageFor(e));
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) return false;
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Web client id from `google-services.json` (the entry with
  /// `client_type: 3`). Credential Manager needs it to mint an ID token whose
  /// audience Firebase will accept; without it sign-in fails at the exchange.
  static const String _serverClientId =
      '594343981380-reoip4ctnbhdfvr93run9n12nhsjo9d8.apps.googleusercontent.com';

  bool _googleInitialized = false;

  /// [GoogleSignIn.initialize] must complete once before anything else on the
  /// instance is called.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleInitialized = true;
  }

  static String _googleMessageFor(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'No Google account is available on this device. Add one in '
            'Settings, then try again.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not configured for this build.';
      default:
        return 'Google sign-in failed (${e.code.name}).';
    }
  }

  static bool _isCancellation(String code) => const {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'user-cancelled',
    'web-context-canceled',
  }.contains(code);

  /// Provider ids on the current account, e.g. `password`, `google.com`.
  Set<String> get providerIds =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toSet() ??
      const {};

  /// True when the account can sign in with an email and password.
  ///
  /// Google-only accounts have no password credential, so email sign-in would
  /// fail for them until one is linked.
  bool get hasPasswordProvider => providerIds.contains('password');

  bool get hasGoogleProvider => providerIds.contains(_googleProviderId);

  static const String _googleProviderId = 'google.com';

  /// Adds an email/password credential to the signed-in account, so it can
  /// use either sign-in method from then on.
  ///
  /// Firebase requires a recent session for this, so an expired one is
  /// refreshed with Google before retrying.
  Future<void> linkEmailPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Sign in again before setting a password.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthFailure(
        'This account has no email address, so a password cannot be added.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        throw AuthFailure(_messageFor(e));
      }

      // Prove ownership again, then retry once.
      try {
        await _reauthenticateWithGoogle(user);
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (retryError) {
        throw AuthFailure(_messageFor(retryError));
      }
    }

    await _auth.currentUser?.reload();
  }

  /// Replaces the password on an account that already has one.
  ///
  /// Use [linkEmailPassword] instead when the account has no password yet —
  /// Firebase treats adding a credential and changing one as different
  /// operations.
  Future<void> updatePassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Sign in again before changing your password.');
    }

    try {
      await user.updatePassword(password);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login' || !hasGoogleProvider) {
        throw AuthFailure(_messageFor(e));
      }

      // Same reauth-and-retry as linking: an old session is not a real error.
      try {
        await _reauthenticateWithGoogle(user);
        await user.updatePassword(password);
      } on FirebaseAuthException catch (retryError) {
        throw AuthFailure(_messageFor(retryError));
      }
    }
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }

    // Same native picker as sign-in, so proving ownership again is a tap
    // rather than another password prompt.
    await _ensureGoogleInitialized();
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
      return;
    }

    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure('Google did not confirm your identity.');
    }

    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    // Also drop the Google session, or the next sign-in silently reuses the
    // same account instead of offering the picker.
    if (!kIsWeb && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google sign-out failed (signing out anyway): $error');
      }
    }
    await _auth.signOut();
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'operation-not-allowed':
        return 'Email sign-in is disabled. Enable the Email/Password provider '
            'in the Firebase console.';
      case 'weak-password':
        return 'That password is too weak. Use at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not set up for this project yet. '
            'Enable the Email/Password provider in the Firebase console.';
      case 'provider-already-linked':
        return 'This account already has a password.';
      case 'credential-already-in-use':
        return 'That email and password belong to another account.';
      case 'requires-recent-login':
        return 'For security, sign in again before changing your password.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in window. Allow popups '
            'for this site and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with that email. Sign in with your '
            'password instead.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for sign-in. Add it under '
            'Authentication > Settings > Authorized domains.';
      default:
        // The web SDK sometimes returns a bare "Error" here, so always keep
        // the code — it is the only diagnosable part.
        final detail = e.message?.trim();
        return (detail == null || detail.isEmpty || detail == 'Error')
            ? 'Sign-in failed (${e.code}).'
            : '$detail (${e.code})';
    }
  }
}
