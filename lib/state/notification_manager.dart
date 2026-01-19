import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _timelineLikesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _replyNotificationsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _resonanceNotificationsSub;
  bool _followersInitialized = false;
  bool _likesInitialized = false;
  bool _timelineLikesInitialized = false;
  Set<String> _knownFollowerIds = const {};
  Set<String> _knownLikeIds = const {};
  final Map<String, Set<String>> _knownTimelineLikes = {};
  Set<String> _knownReplyNotificationIds = const {};
  Set<String> _knownResonanceNotificationIds = const {};
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
    final body = message?.trim().isNotEmpty == true ? message!.trim() : '';
    _appendNotification(
      AppNotification(
        id: _uuid.v4(),
        type: AppNotificationType.encounter,
        title: title,
        message: body,
        createdAt: encounteredAt,
        profile: profile,
        encounterId: encounterId,
        read: false,
      ),
    );
  }

  /// リプライ通知を追加
  Future<void> addReplyNotification({
    required String replierProfileId,
    required String replierName,
    required String postId,
    required String caption,
    Profile? replierProfile,
  }) async {
    // 自分自身へのリプライは通知しない
    if (replierProfileId == _localProfile.id) return;

    Profile? profile = replierProfile;
    if (profile == null) {
      try {
        profile = await _interactionService.loadProfile(replierProfileId);
      } catch (_) {
        // プロフィール取得失敗時は簡易プロフィールを使用
      }
    }
    profile ??= Profile(
      id: replierProfileId,
      beaconId: replierProfileId,
      displayName: replierName,
      username: null,
      bio: '',
      homeTown: '',
      favoriteGames: const [],
      avatarColor: Colors.grey,
    );

    final snippet = _buildReplySnippet(caption);
    _appendNotification(
      AppNotification(
        id: _uuid.v4(),
        type: AppNotificationType.reply,
        title: snippet,
        message: '',
        createdAt: DateTime.now(),
        profile: profile,
        postId: postId,
      ),
    );
  }

  String _buildReplySnippet(String caption) {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return '投稿にリプライが届きました';
    }
    const maxLength = 24;
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    final shortened = '${trimmed.substring(0, maxLength)}…';
    return shortened;
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

  Future<void> refresh() async {
    // 既存の監視をリスタートして最新状態と同期
    _restartSubscriptions();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    _replyNotificationsSub?.cancel();
    _resonanceNotificationsSub?.cancel();
    super.dispose();
  }

  void pauseForLogout() {
    _paused = true;
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    _replyNotificationsSub?.cancel();
    _resonanceNotificationsSub?.cancel();
    _followersSub = null;
    _likesSub = null;
    _timelineLikesSub = null;
    _replyNotificationsSub = null;
    _resonanceNotificationsSub = null;
    _followersInitialized = false;
    _likesInitialized = false;
    _timelineLikesInitialized = false;
    _knownFollowerIds = const {};
    _knownLikeIds = const {};
    _knownTimelineLikes.clear();
    _knownReplyNotificationIds = const {};
    _knownResonanceNotificationIds = const {};
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

  bool hasFollowedMe(String profileId) {
    return _knownFollowerIds.contains(profileId);
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
    _startReplyNotificationSubscription();
    _startResonanceNotificationSubscription();
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

  void _startReplyNotificationSubscription() {
    if (_paused || !_hasAuthUser) {
      return;
    }
    _replyNotificationsSub?.cancel();
    final profileId = _localProfile.id;
    if (profileId.isEmpty) {
      return;
    }
    // 複合インデックス不要のシンプルなクエリ
    _replyNotificationsSub = FirebaseFirestore.instance
        .collection('profiles')
        .doc(profileId)
        .collection('notifications')
        .where('type', isEqualTo: 'reply')
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) => unawaited(_handleReplyNotifications(snapshot)),
      onError: (error, stackTrace) {
        debugPrint('リプライ通知の監視に失敗: $error');
      },
    );
  }

  Future<void> _handleReplyNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    debugPrint('リプライ通知: ${snapshot.docs.length}件のドキュメントを受信');
    final currentIds = snapshot.docs.map((doc) => doc.id).toSet();

    // 初回は既存の通知IDを記録するだけ
    if (_knownReplyNotificationIds.isEmpty && currentIds.isNotEmpty) {
      debugPrint('リプライ通知: 初回ロード、${currentIds.length}件を記録');
      _knownReplyNotificationIds = currentIds;
      return;
    }

    final newIds = currentIds.difference(_knownReplyNotificationIds);
    debugPrint('リプライ通知: 新規${newIds.length}件');
    for (final id in newIds) {
      final doc = snapshot.docs.firstWhere((d) => d.id == id);
      final data = doc.data();
      final fromUserId = data['fromUserId'] as String? ?? '';
      final fromUserName = data['fromUserName'] as String? ?? 'Unknown';
      final postId = data['postId'] as String? ?? '';
      final replyId = data['replyId'] as String?;
      final caption = data['caption'] as String? ?? '';

      debugPrint(
          'リプライ通知: fromUserId=$fromUserId, postId=$postId, replyId=$replyId');

      if (fromUserId.isEmpty || fromUserId == _localProfile.id) continue;

      final profile = Profile(
        id: fromUserId,
        beaconId: fromUserId,
        displayName: fromUserName,
        username: data['fromUserUsername'] as String?,
        bio: '',
        homeTown: '',
        favoriteGames: const [],
        avatarColor: Colors.grey,
        avatarImageBase64: data['fromUserAvatarBase64'] as String?,
      );

      final snippet = _buildReplySnippet(caption);
      _appendNotification(
        AppNotification(
          id: _uuid.v4(),
          type: AppNotificationType.reply,
          title: snippet,
          message: '',
          createdAt: DateTime.now(),
          profile: profile,
          postId: postId,
          replyId: replyId,
          read: false,
        ),
      );
    }
    _knownReplyNotificationIds = currentIds;
  }

  void _startResonanceNotificationSubscription() {
    if (_paused || !_hasAuthUser) {
      return;
    }
    _resonanceNotificationsSub?.cancel();
    final profileId = _localProfile.id;
    if (profileId.isEmpty) {
      return;
    }
    _resonanceNotificationsSub = FirebaseFirestore.instance
        .collection('profiles')
        .doc(profileId)
        .collection('notifications')
        .where('type', isEqualTo: 'resonance')
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) => unawaited(_handleResonanceNotifications(snapshot)),
      onError: (error, stackTrace) {
        debugPrint('共鳴通知の監視に失敗: $error');
      },
    );
  }

  Future<void> _handleResonanceNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    debugPrint('共鳴通知: ${snapshot.docs.length}件のドキュメントを受信');
    final currentIds = snapshot.docs.map((doc) => doc.id).toSet();

    // 初回ロード時も含めて全ての通知を処理する
    // (リプライ通知とは異なり、共鳴通知は既存のものも表示する)
    final isFirstLoad = _knownResonanceNotificationIds.isEmpty;
    final idsToProcess = isFirstLoad
        ? currentIds
        : currentIds.difference(_knownResonanceNotificationIds);

    debugPrint(
        '共鳴通知: ${isFirstLoad ? "初回ロード" : "新規"}${idsToProcess.length}件を処理');

    for (final id in idsToProcess) {
      final doc = snapshot.docs.firstWhere((d) => d.id == id);
      final data = doc.data();
      final fromUserId = data['fromUserId'] as String? ?? '';
      final fromUserName = data['fromUserName'] as String? ?? 'Unknown';
      final message = data['message'] as String? ?? '';
      final createdAt = data['createdAt'] as Timestamp?;

      debugPrint('共鳴通知: fromUserId=$fromUserId');

      if (fromUserId.isEmpty || fromUserId == _localProfile.id) continue;

      final profile = Profile(
        id: fromUserId,
        beaconId: fromUserId,
        displayName: fromUserName,
        username: data['fromUserUsername'] as String?,
        bio: '',
        homeTown: '',
        favoriteGames: const [],
        avatarColor: Colors.grey,
        avatarImageBase64: data['fromUserAvatarBase64'] as String?,
      );

      _appendNotification(
        AppNotification(
          id: _uuid.v4(),
          type: AppNotificationType.resonance,
          title: '${profile.displayName}さんと共鳴しました',
          message: message,
          createdAt: createdAt?.toDate() ?? DateTime.now(),
          profile: profile,
          read: false,
        ),
      );
    }
    _knownResonanceNotificationIds = currentIds;
  }

  void _restartSubscriptions() {
    _followersSub?.cancel();
    _likesSub?.cancel();
    _timelineLikesSub?.cancel();
    _replyNotificationsSub?.cancel();
    _resonanceNotificationsSub?.cancel();
    _followersInitialized = false;
    _likesInitialized = false;
    _timelineLikesInitialized = false;
    _knownFollowerIds = const {};
    _knownLikeIds = const {};
    _knownTimelineLikes.clear();
    _knownReplyNotificationIds = const {};
    _knownResonanceNotificationIds = const {};
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
    _knownFollowerIds = currentIds;
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
          message: '',
          createdAt: snapshot.followedAt ?? DateTime.now(),
          profile: profile,
        ),
      );
    }
  }

  Future<void> _handleLikes(List<ProfileLikeSnapshot> snapshots) async {
    final currentIds = snapshots.map((snapshot) => snapshot.profile.id).toSet();
    if (!_likesInitialized) {
      _knownLikeIds = currentIds;
      _likesInitialized = true;
      return;
    }
    final newIds = currentIds.difference(_knownLikeIds);
    _knownLikeIds = currentIds;
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
          message: '',
          createdAt: snapshot.likedAt ?? DateTime.now(),
          profile: profile,
        ),
      );
    }
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
        unawaited(_notifyTimelineLike(likerId, caption, doc.id));
      }
    }
    _knownTimelineLikes
      ..clear()
      ..addAll(nextKnown);
    _timelineLikesInitialized = true;
  }

  void _appendNotification(AppNotification notification) {
    // Check for duplicates
    final isDuplicate = _notifications.any((n) {
      if (n.type != notification.type) return false;
      // For follow and like, check based on the profile ID
      if (n.type == AppNotificationType.follow ||
          n.type == AppNotificationType.like) {
        return n.profile?.id == notification.profile?.id;
      }
      // For replies, check based on the post ID and the source profile
      if (n.type == AppNotificationType.reply) {
        return n.postId == notification.postId &&
            n.profile?.id == notification.profile?.id &&
            n.title == notification.title; // Check content too
      }
      // For timeline likes, check based on profile and title
      if (n.type == AppNotificationType.timelineLike) {
        return n.profile?.id == notification.profile?.id &&
            n.title == notification.title;
      }
      // For resonance, check based on profile ID
      if (n.type == AppNotificationType.resonance) {
        return n.profile?.id == notification.profile?.id;
      }
      return false;
    });

    if (isDuplicate) {
      debugPrint('重複通知をスキップ: ${notification.title}');
      return;
    }

    _notifications.add(notification);
    _notifications.sort(_sortByNewest);
    notifyListeners();
  }

  Future<void> _notifyTimelineLike(
      String likerId, String caption, String postId) async {
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
          title: snippet,
          message: '',
          createdAt: DateTime.now(),
          profile: profile,
          postId: postId,
        ),
      );
    } catch (error) {
      debugPrint('タイムラインいいね通知の生成に失敗: $error');
    }
  }

  String _buildTimelineLikeSnippet(String caption) {
    final trimmed = caption.trim();
    if (trimmed.isEmpty) {
      return '投稿にいいねされました';
    }
    const maxLength = 24;
    if (trimmed.length <= maxLength) {
      return '$trimmedにいいねされました';
    }
    final shortened = '${trimmed.substring(0, maxLength)}…';
    return '$shortenedにいいねされました';
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
