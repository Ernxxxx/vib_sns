import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

Timer? _anonymousRetryTimer;

/// Ensures there is an anonymous FirebaseAuth user available.
/// Retries a few times immediately, then schedules periodic retries until
/// authentication succeeds so the app can recover without a restart.
Future<User?> ensureAnonymousAuth({int attempts = 3}) async {
  final auth = FirebaseAuth.instance;
  final existing = auth.currentUser;
  if (existing != null) {
    return existing;
  }
  for (var i = 0; i < attempts; i++) {
    try {
      final cred = await auth.signInAnonymously();
      _cancelAnonymousRetryTimer();
      return cred.user;
    } catch (error) {
      debugPrint('Anonymous sign-in attempt ${i + 1} failed: $error');
      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
  debugPrint(
      'Anonymous sign-in failed after $attempts attempts; scheduling background retry.');
  _scheduleAnonymousRetry();
  return auth.currentUser;
}

void _scheduleAnonymousRetry() {
  if (_anonymousRetryTimer != null) {
    return;
  }
  _anonymousRetryTimer =
      Timer.periodic(const Duration(seconds: 5), (Timer timer) async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      _cancelAnonymousRetryTimer();
      return;
    }
    try {
      final cred = await auth.signInAnonymously();
      if (cred.user != null) {
        debugPrint('Anonymous sign-in retry succeeded.');
        _cancelAnonymousRetryTimer();
      }
    } catch (error) {
      debugPrint('Anonymous sign-in retry failed: $error');
      await auth.signOut();
    }
  });
}

void _cancelAnonymousRetryTimer() {
  _anonymousRetryTimer?.cancel();
  _anonymousRetryTimer = null;
}

Future<UserCredential?> signInWithGoogle() async {
  final googleSignIn = GoogleSignIn();
  GoogleSignInAccount? account;
  try {
    account = await googleSignIn.signIn();
  } catch (error) {
    debugPrint('Google sign-in failed to start: $error');
    rethrow;
  }
  if (account == null) {
    return null;
  }
  final auth = await account.authentication;
  final credential = GoogleAuthProvider.credential(
    idToken: auth.idToken,
    accessToken: auth.accessToken,
  );
  final firebaseAuth = FirebaseAuth.instance;
  final currentUser = firebaseAuth.currentUser;
  if (currentUser != null && currentUser.isAnonymous) {
    try {
      return await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use') {
        await firebaseAuth.signOut();
        return await firebaseAuth.signInWithCredential(credential);
      }
      rethrow;
    }
  }
  return await firebaseAuth.signInWithCredential(credential);
}
