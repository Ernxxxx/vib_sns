import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/profile.dart';
import '../services/profile_interaction_service.dart';

class NotificationManager extends ChangeNotifier {
  NotificationManager({
    required ProfileInteractionService interactionService,
    required Profile localProfile,
    bool startPaused = false,
  })  : _interactionService = interactionService,
        _localProfile = localProfile,
        _paused = startPaused || FirebaseAuth.instance.currentUser == null {
    _authSubscription =
        FirebaseAuth.instance.userChanges().listen((User? user) {
      if (user != null && !_paused) {
        _startSubscriptions();
      }
    });
    if (!_paused) {
      _startSubscriptions();
    }
  }

  final ProfileInteractionService _interactionService;
  Profile _localProfile;
  final List<AppNotification> _notifications = [];
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<ProfileFollowSnapshot>>? _followersSub;
  StreamSubscription<List<ProfileLikeSnapshot>>? _likesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _timelineLikesSub;
  bool _followersInitialized = false;
  bool _likesInitialized = false;
  bool _timelineLikesInitialized = false;
  Set<String> _knownFollowerIds = const {};
  Set<String> _knownLikeIds = const {};
  final Map<String, Set<String>> _knownTimelineLikes = {};
  bool _paused;
  StreamSubscription<User?>? _authSubscription;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications..sort(_sortByNewest));

  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;

  void registerEncounter({
    required Profile profile,
    required DateTime encounteredAt,
    String? encounterId,
    String? message,
    bool isRepeat = false,
  }) {
    final title = isRepeat
        ? '${profile.displayName}さんとまたすれ違いました'
        : '${profile.displayName}さんとすれ違いました';
    final body = message?.trim().isNotEmpty == true
        ? message!.trim()
        : 'プロフィールを確認してみましょう。';
    _appendNotification(
      AppNotification(
        id: _uuid.v4(),
        type: AppNotificationType.encounter,
        title: title,
        message: body,
        createdAt: encounteredAt,
        profile: profile,
        encounterId: encounterId,
      ),
    );
  }

  void markEncounterNotificationsRead(String encounterId) {
    var changed = false;
    for (final notification in _notifications) {
      if (notification.encounterId == encounterId && !notification.read) {
        notification.markRead();
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void markNotificationRead(String notificationId) {
    for (final notification in _notifications) {
      if (notification.id == notificationId && !notification.read) {
        notification.markRead();
        notifyListeners();
        break;
      }
    }
  }

  void markAllRead() {
    var changed = false;
    for (final notification in _notifications) {
      if (!notification.read) {
        notification.markRead();
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void updateLocalProfile(Profile profile) {
    if (profile.id == _localProfile.id) {
      _localProfile = profile;
      return;
    }
    _localProfile = profile;
    _restartSubscriptions();
  }

  Future<void> resetForProfile(Profile profile) async {
    await _followersSub?.cancel();
    await _likesSub?.cancel();
    await _timelineLikesSub?.cancel();
    _followersSub = null;
    _likesSub = null;
    _timelineLikesSub = null;
    _followersInitialized = false;
    _likesInitialized = false;
    _timelineLikesInitialized = false;
    _knownFollowerIds = const {};
    _knownLikeIds = const {};
    _knownTimelineLikes.clear();
    _notifications.clear();
    _localProfile = profile;
    if (!_paused) {
      _startSubscriptions();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    super.dispose();
  }

  void pauseForLogout() {
    _paused = true;
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    _followersSub = null;
    _likesSub = null;
    _timelineLikesSub = null;
    _followersInitialized = false;
    _likesInitialized = false;
    _timelineLikesInitialized = false;
    _knownFollowerIds = const {};
    _knownLikeIds = const {};
    _knownTimelineLikes.clear();
    _notifications.clear();
    notifyListeners();
  }

  void resumeAfterLogin(Profile profile) {
    _paused = false;
    _localProfile = profile;
    _startSubscriptions();
  }

  bool hasLikedMe(String profileId) {
    return _knownLikeIds.contains(profileId);
  }

  void _startSubscriptions() {
    if (_paused) {
      return;
    }
    if (!_hasAuthUser) {
      debugPrint(
          'NotificationManager: deferring subscriptions until FirebaseAuth user is available');
      return;
    }
    _followersSub = _interactionService
        .watchFollowers(
      targetId: _localProfile.id,
      viewerId: _localProfile.id,
    )
        .listen(
      (snapshots) => unawaited(_handleFollowers(snapshots)),
      onError: (error, stackTrace) {
        debugPrint('通知フォロワー監視に失敗: $error');
      },
    );
    _likesSub = _interactionService
        .watchLikes(
      targetId: _localProfile.id,
      viewerId: _localProfile.id,
    )
        .listen(
      (snapshots) => unawaited(_handleLikes(snapshots)),
      onError: (error, stackTrace) {
        debugPrint('通知いいね監視に失敗: $error');
      },
    );

    _startTimelineLikeSubscription();
  }

  void _startTimelineLikeSubscription() {
    if (_paused || !_hasAuthUser) {
      return;
    }
    _timelineLikesSub?.cancel();
    final profileId = _localProfile.id;
    if (profileId.isEmpty) {
      return;
    }
    _timelineLikesSub = FirebaseFirestore.instance
        .collection('timelinePosts')
        .where('authorId', isEqualTo: profileId)
        .snapshots()
        .listen(
      (snapshot) => unawaited(_handleTimelinePosts(snapshot)),
      onError: (error, stackTrace) {
        debugPrint('タイムライン投稿の監視に失敗: $error');
      },
    );
  }

  void _restartSubscriptions() {
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    _followersInitialized = false;
    _likesInitialized = false;
    _timelineLikesInitialized = false;
    _knownFollowerIds = const {};
    _knownLikeIds = const {};
    _knownTimelineLikes.clear();
    if (_paused) {
      return;
    }
    _startSubscriptions();
  }

  Future<void> _handleFollowers(List<ProfileFollowSnapshot> snapshots) async {
    final currentIds = snapshots.map((snapshot) => snapshot.profile.id).toSet();
    if (!_followersInitialized) {
      _knownFollowerIds = currentIds;
      _followersInitialized = true;
      return;
    }
    final newIds = currentIds.difference(_knownFollowerIds);
    for (final id in newIds) {
      final snapshot =
          snapshots.firstWhere((element) => element.profile.id == id);
      // Do not notify for actions performed by the local profile itself.
      if (snapshot.profile.id == _localProfile.id ||
          snapshot.profile.beaconId == _localProfile.beaconId) continue;
      final profile = await _resolveProfile(
        snapshot.profile,
        isFollowedByViewer: snapshot.isFollowedByViewer,
      );
      _appendNotification(
        AppNotification(
          id: _uuid.v4(),
          type: AppNotificationType.follow,
          title: '${profile.displayName}さんがあなたをフォローしました',
          message: 'フォローバックしてみましょう。',
          createdAt: snapshot.followedAt ?? DateTime.now(),
          profile: profile,
        ),
      );
    }
    _knownFollowerIds = currentIds;
  }

  Future<void> _handleLikes(List<ProfileLikeSnapshot> snapshots) async {
    final currentIds = snapshots.map((snapshot) => snapshot.profile.id).toSet();
    if (!_likesInitialized) {
      _knownLikeIds = currentIds;
      _likesInitialized = true;
      return;
    }
    final newIds = currentIds.difference(_knownLikeIds);
    for (final id in newIds) {
      final snapshot =
          snapshots.firstWhere((element) => element.profile.id == id);
      // Skip notifications when the actor is the local profile.
      if (snapshot.profile.id == _localProfile.id ||
          snapshot.profile.beaconId == _localProfile.beaconId) continue;
      final profile = await _resolveProfile(
        snapshot.profile,
        isFollowedByViewer: snapshot.isFollowedByViewer,
      );
      _appendNotification(
        AppNotification(
          id: _uuid.v4(),
          type: AppNotificationType.like,
          title: '${profile.displayName}さんがあなたにいいねしました',
          message: 'お返しにいいねやフォローをしてみませんか？',
          createdAt: snapshot.likedAt ?? DateTime.now(),
          profile: profile,
        ),
      );
    }
    _knownLikeIds = currentIds;
  }

  Future<void> _handleTimelinePosts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final nextKnown = <String, Set<String>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final likedByRaw = data['likedBy'];
      final likedBy = likedByRaw is Iterable
          ? likedByRaw.map((e) => e.toString()).toSet()
          : <String>{};
      nextKnown[doc.id] = likedBy;
      if (!_timelineLikesInitialized) {
        continue;
      }
      final previous = _knownTimelineLikes[doc.id] ?? const <String>{};
      final newLikers = likedBy.difference(previous);
      if (newLikers.isEmpty) continue;
      final caption = data['caption']?.toString() ?? '';
      for (final likerId in newLikers) {
        if (likerId.isEmpty || likerId == _localProfile.id) continue;
        unawaited(_notifyTimelineLike(likerId, caption));
      }
    }
    _knownTimelineLikes
      ..clear()
      ..addAll(nextKnown);
    _timelineLikesInitialized = true;
  }

  void _appendNotification(AppNotification notification) {
    _notifications.add(notification);
    _notifications.sort(_sortByNewest);
    notifyListeners();
  }

  Future<void> _notifyTimelineLike(String likerId, String caption) async {
    try {
      final profile = await _interactionService.loadProfile(likerId);
      if (profile == null) {
        return;
      }
      final snippet = _buildTimelineLikeSnippet(caption);
      _appendNotification(
        AppNotification(
          id: _uuid.v4(),
          type: AppNotificationType.timelineLike,
          title: '${profile.displayName}さんがあなたの投稿にいいねしました',
          message: snippet,
          createdAt: DateTime.now(),
          profile: profile,
        ),
      );
    } catch (error) {
      debugPrint('タイムラインいいね通知の生成に失敗: $error');
    }
  }

  String _buildTimelineLikeSnippet(String caption) {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return '投稿した写真にリアクションが届きました。';
    }
    const maxLength = 24;
    if (trimmed.length <= maxLength) {
      return '「$trimmed」にいいねされました。';
    }
    final shortened = '${trimmed.substring(0, maxLength)}…';
    return '「$shortened」にいいねされました。';
  }

  Future<Profile> _resolveProfile(
    Profile profile, {
    bool? isFollowedByViewer,
  }) async {
    try {
      final fresh = await _interactionService.loadProfile(profile.id);
      if (fresh != null) {
        final fallbackName = profile.displayName.trim();
        final currentName = fresh.displayName.trim();
        final resolvedName = currentName.isNotEmpty && currentName != 'Unknown'
            ? currentName
            : (fallbackName.isNotEmpty && fallbackName != 'Unknown'
                ? fallbackName
                : currentName);
        final resolvedAvatar =
            (profile.avatarImageBase64?.trim().isNotEmpty ?? false)
                ? profile.avatarImageBase64
                : fresh.avatarImageBase64;
        return fresh.copyWith(
          displayName: resolvedName,
          avatarImageBase64: resolvedAvatar,
          avatarColor: profile.avatarColor,
          following: isFollowedByViewer ?? fresh.following,
        );
      }
    } catch (error) {
      debugPrint('通知プロフィールの取得に失敗: $error');
    }
    return profile.copyWith(following: isFollowedByViewer ?? profile.following);
  }

  static int _sortByNewest(AppNotification a, AppNotification b) {
    return b.createdAt.compareTo(a.createdAt);
  }

  bool get _hasAuthUser => FirebaseAuth.instance.currentUser != null;
}
