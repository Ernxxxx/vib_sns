import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_streetpass_service.dart';
import '../state/emotion_map_manager.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import '../utils/auth_helpers.dart';
import 'profile_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;

  Future<void> _openProfileEdit() async {
    final controller = context.read<ProfileController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: controller.profile),
      ),
    );
    if (result == true && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました。')),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？\nアカウントデータは保持されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _logoutOnly();
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('アカウント削除'),
        content: const Text(
          'アカウントを削除しますか？\n\n'
          'この操作は取り消せません。\n'
          'すべてのプロフィール情報、投稿、フォロー関係が削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAccountAndLogout();
            },
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutOnly() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final controller = context.read<ProfileController>();
    final manager = context.read<EncounterManager>();
    final notificationManager = context.read<NotificationManager>();
    final timelineManager = context.read<TimelineManager>();
    final emotionMapManager = context.read<EmotionMapManager>();
    try {
      manager.pauseProfileSync();
      notificationManager.pauseForLogout();
      timelineManager.pauseForLogout();
      emotionMapManager.pauseForLogout();

      await FirebaseAuth.instance.signOut();
      await timelineManager.clearPostsForCurrentProfile();

      await LocalProfileLoader.resetLocalProfile(wipeIdentity: true);
      final refreshed = await LocalProfileLoader.loadOrCreate();

      if (mounted) {
        await manager.switchLocalProfile(refreshed, skipSync: true);
        controller.updateStats(
            followersCount: 0, followingCount: 0, receivedLikes: 0);
        controller.updateProfile(refreshed, needsSetup: true);
        await ensureAnonymousAuth();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccountAndLogout() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final controller = context.read<ProfileController>();
    final manager = context.read<EncounterManager>();
    final notificationManager = context.read<NotificationManager>();
    final timelineManager = context.read<TimelineManager>();
    final emotionMapManager = context.read<EmotionMapManager>();
    try {
      manager.pauseProfileSync();
      notificationManager.pauseForLogout();
      timelineManager.pauseForLogout();
      emotionMapManager.pauseForLogout();

      try {
        await _deleteStreetpassPresence(
          profileId: controller.profile.id,
          beaconId: controller.profile.beaconId,
        );
      } catch (e) {
        debugPrint('Failed to delete streetpass presence: $e');
      }

      final user = FirebaseAuth.instance.currentUser;
      var serverDeleted = false;
      if (user != null) {
        try {
          final callable =
              FirebaseFunctions.instance.httpsCallable('deleteUserProfile');
          await callable.call(<String, dynamic>{
            'profileId': controller.profile.id,
            'beaconId': controller.profile.beaconId,
          });
          serverDeleted = true;
        } catch (e) {
          debugPrint('deleteUserProfile failed: $e');
          await _purgeProfileData(
            profileId: controller.profile.id,
            beaconId: controller.profile.beaconId,
          );
        }
      }

      await FirebaseAuth.instance.signOut();
      await timelineManager.clearPostsForCurrentProfile();

      await LocalProfileLoader.resetLocalProfile(wipeIdentity: true);
      final refreshed = await LocalProfileLoader.loadOrCreate();

      if (mounted) {
        if (serverDeleted) {
          await manager.switchLocalProfile(refreshed, skipSync: true);
          controller.updateStats(
              followersCount: 0, followingCount: 0, receivedLikes: 0);
          controller.updateProfile(refreshed, needsSetup: true);
        } else {
          await manager.switchLocalProfile(refreshed, skipSync: true);
          controller.updateStats(
              followersCount: 0, followingCount: 0, receivedLikes: 0);
          controller.updateProfile(refreshed, needsSetup: true);
        }

        await ensureAnonymousAuth();

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStreetpassPresence({
    required String profileId,
    required String beaconId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final presences = firestore.collection('streetpass_presences');

    String? deviceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString(FirestoreStreetPassService.prefsDeviceIdKey);
    } catch (_) {}

    if (deviceId != null && deviceId.isNotEmpty) {
      try {
        await presences.doc(deviceId).delete();
      } catch (_) {}
    }

    if (profileId != deviceId) {
      try {
        await presences.doc(profileId).delete();
      } catch (_) {}
    }

    // クリーンアップ処理はエラーが出ても続行
    try {
      final byProfileId =
          await presences.where('profile.id', isEqualTo: profileId).get();
      for (final doc in byProfileId.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Future<void> _purgeProfileData({
    required String profileId,
    required String beaconId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection('profiles').doc(profileId).delete();
    } catch (_) {}
    try {
      await _deleteStreetpassPresence(profileId: profileId, beaconId: beaconId);
    } catch (_) {}
    try {
      final timeline = await firestore
          .collection('timelinePosts')
          .where('authorId', isEqualTo: profileId)
          .get();
      for (final doc in timeline.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  Uint8List? _decodeAvatarBytes(String? base64) {
    if (base64 == null || base64.trim().isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(base64.trim());
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<ProfileController>().profile;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('設定'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // プロフィールカード
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final avatarBytes =
                                  _decodeAvatarBytes(profile.avatarImageBase64);
                              return CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey,
                                backgroundImage: avatarBytes != null
                                    ? MemoryImage(avatarBytes)
                                    : null,
                                child: avatarBytes == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white, size: 30)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (profile.username != null)
                                  Text(
                                    '@${profile.username}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader(context, 'アカウント'),
                _buildSettingsTile(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'プロフィール編集',
                  onTap: _openProfileEdit,
                ),

                const SizedBox(height: 24),
                _buildSectionHeader(context, 'アプリについて'),
                _buildSettingsTile(
                  context,
                  icon: Icons.description_outlined,
                  title: '利用規約',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'プライバシーポリシー',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionHeader(context, 'ログイン'),
                _buildSettingsTile(
                  context,
                  icon: Icons.logout,
                  title: 'ログアウト',
                  textColor: theme.colorScheme.primary,
                  iconColor: theme.colorScheme.primary,
                  onTap: _showLogoutConfirmation,
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever_outlined,
                  title: 'アカウント削除',
                  textColor: theme.colorScheme.error,
                  iconColor: theme.colorScheme.error,
                  onTap: _showDeleteAccountConfirmation,
                  showArrow: false,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    bool showArrow = true,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? theme.colorScheme.onSurface).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: textColor ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: showArrow
          ? Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              size: 20,
            )
          : null,
    );
  }
}
