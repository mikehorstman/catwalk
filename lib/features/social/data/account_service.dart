import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/social_models.dart';

/// The shared account service. Tests replace it with [FakeAccountService].
final accountServiceProvider = Provider<AccountService>(
  (ref) => FirebaseAccountService(),
);

/// Signing in and out. Walking never needs it: the app works without an account.
abstract class AccountService {
  /// Who is signed in now, or null.
  AccountUser? get current;

  /// Signs in with Google. Null when the player backs out or it fails.
  Future<AccountUser?> signInWithGoogle();

  /// Signs out.
  Future<void> signOut();
}

/// Used by tests: signs in as a chosen user without any network.
class FakeAccountService implements AccountService {
  FakeAccountService({this.user, this.willSignIn});

  /// Who is signed in.
  AccountUser? user;

  /// Who the next sign-in gives. Null makes sign-in fail.
  AccountUser? willSignIn;

  @override
  AccountUser? get current => user;

  @override
  Future<AccountUser?> signInWithGoogle() async => user = willSignIn;

  @override
  Future<void> signOut() async => user = null;
}

/// Google sign-in on top of Firebase Auth.
class FirebaseAccountService implements AccountService {
  /// The web client of the Firebase project; Android needs it to get an ID token.
  static const _serverClientId =
      '64019969968-j288heikjqsgr71digk3iha1ftvlhm7e.apps.googleusercontent.com';

  /// The iOS client from `GoogleService-Info.plist`.
  static const _iosClientId =
      '64019969968-u4hejagsivivft0lgjd4fcjjkb27nqgd.apps.googleusercontent.com';

  bool _ready = false;

  @override
  AccountUser? get current {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return null;
      return _toUser(user);
    } catch (_) {
      return null;
    }
  }

  AccountUser _toUser(User user) => AccountUser(
    uid: user.uid,
    name: user.displayName ?? user.email?.split('@').first ?? 'Walker',
    photoUrl: user.photoURL,
  );

  @override
  Future<AccountUser?> signInWithGoogle() async {
    try {
      if (!_ready) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _serverClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? _iosClientId
              : null,
        );
        _ready = true;
      }
      final google = await GoogleSignIn.instance.authenticate();
      final idToken = google.authentication.idToken;
      if (idToken == null) return null;
      final result = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = result.user;
      return user == null ? null : _toUser(user);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Sign-out failed: $e');
    }
  }
}
