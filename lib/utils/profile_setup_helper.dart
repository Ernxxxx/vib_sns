import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../services/profile_interaction_service.dart';
import '../state/emotion_map_manager.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import 'auth_helpers.dart';

/// ユーザー名が既に使われている場合にスローされる例外
class UsernameAlreadyTakenException implements Exception {
  UsernameAlreadyTakenException(this.username);
  final String username;

  @override
  String toString() => 'ユーザーID「@$username」は既に使用されています。';
}

Future<void> syncUsernameReservation({
  required String profileId,
  required String authUid,
  String? currentUsername,
  String? nextUsername,
}) async {
  final firestore = FirebaseFirestore.instance;
  await firestore
      .collection('profiles')
      .doc(profileId)
      .set({'authUid': authUid}, SetOptions(merge: true));
  final normalizedNext = Profile.normalizeUsername(nextUsername);
  if (normalizedNext == null || normalizedNext.isEmpty) {
    return;
  }
  final normalizedCurrent = Profile.normalizeUsername(currentUsername);
  final profileRef = firestore.collection('profiles').doc(profileId);
  final usernames = firestore.collection('usernames');

  final legacyQuery = await firestore
      .collection('profiles')
      .where('username', isEqualTo: normalizedNext)
      .limit(1)
      .get();
  if (legacyQuery.docs.isNotEmpty &&
      legacyQuery.docs.first.id != profileId) {
    throw UsernameAlreadyTakenException(normalizedNext);
  }

  await firestore.runTransaction((transaction) async {
    final nextRef = usernames.doc(normalizedNext);
    final nextSnap = await transaction.get(nextRef);
    final existingProfileId = nextSnap.data()?['profileId']?.toString();
    if (nextSnap.exists && existingProfileId != profileId) {
      throw UsernameAlreadyTakenException(normalizedNext);
    }

    if (normalizedCurrent != null && normalizedCurrent != normalizedNext) {
      final currentRef = usernames.doc(normalizedCurrent);
      final currentSnap = await transaction.get(currentRef);
      final currentOwner = currentSnap.data()?['profileId']?.toString();
      if (currentSnap.exists && currentOwner == profileId) {
        transaction.delete(currentRef);
      }
    }

    if (!nextSnap.exists) {
      transaction.set(nextRef, {
        'profileId': profileId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    transaction.set(
      profileRef,
      {
        'authUid': authUid,
        'username': normalizedNext,
      },
      SetOptions(merge: true),
    );
  });
}

Future<void> completeProfileSetup(
  BuildContext context, {
  required String displayName,
  String? username,
  List<String>? hashtags,
}) async {
  debugPrint(
      'completeProfileSetup: displayName=$displayName username=$username hashtags=$hashtags');

  final normalizedUsername = Profile.normalizeUsername(username);
  final existingProfile = await LocalProfileLoader.loadOrCreate();

  final ensuredUser = await ensureAnonymousAuth();
  final currentUser = ensuredUser ?? FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw StateError('認証情報を取得できませんでした。もう一度お試しください。');
  }
  await syncUsernameReservation(
    profileId: existingProfile.id,
    authUid: currentUser.uid,
    currentUsername: existingProfile.username,
    nextUsername: normalizedUsername,
  );

  final updated = await LocalProfileLoader.updateLocalProfile(
    displayName: displayName,
    username: normalizedUsername,
    favoriteGames: hashtags,
  );
  debugPrint(
      'completeProfileSetup: updated profile username=${updated.username}');

  if (!context.mounted) return;
  final interactionService = context.read<ProfileInteractionService>();
  try {
    await interactionService.bootstrapProfile(updated);
  } catch (e) {
    debugPrint('Failed to bootstrap profile: $e');
  }
  if (!context.mounted) return;

  final manager = context.read<EncounterManager>();
  final profileController = context.read<ProfileController>();
  final notificationManager = context.read<NotificationManager>();
  final timelineManager = context.read<TimelineManager>();
  final emotionMapManager = context.read<EmotionMapManager>();

  notificationManager.resumeAfterLogin(updated);
  timelineManager.resumeAfterLogin();
  emotionMapManager.resumeAfterLogin();
  manager.resumeProfileSync();

  await manager.switchLocalProfile(updated);
  unawaited(manager.start());
  profileController.updateProfile(updated, needsSetup: false);
}
