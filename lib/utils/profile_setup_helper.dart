import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_interaction_service.dart';
import '../state/emotion_map_manager.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import 'auth_helpers.dart';

Future<void> completeProfileSetup(
  BuildContext context, {
  required String displayName,
  List<String>? hashtags,
}) async {
  final updated = await LocalProfileLoader.updateLocalProfile(
    displayName: displayName,
    favoriteGames: hashtags,
  );

  final ensuredUser = await ensureAnonymousAuth();
  final currentUser = ensuredUser ?? FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(updated.id)
          .set({'authUid': currentUser.uid}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to persist authUid on profile: $e');
    }
  }

  if (!context.mounted) return;
  final interactionService = context.read<ProfileInteractionService>();
  await interactionService.bootstrapProfile(updated);
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
