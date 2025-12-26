import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../models/timeline_post.dart';
import '../services/profile_interaction_service.dart';
import '../state/encounter_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import '../utils/auth_helpers.dart';
import '../widgets/like_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_info_tile.dart';
import '../widgets/profile_stats_row.dart';
import 'profile_follow_list_sheet.dart';

class ProfileViewScreen extends StatefulWidget {
  const ProfileViewScreen({
    super.key,
    required this.profileId,
    this.initialProfile,
  });

  final String profileId;
  final Profile? initialProfile;

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  late Profile _profile =
      widget.initialProfile ?? _placeholderProfile(widget.profileId);
  late String _viewerId;
  ProfileInteractionSnapshot? _latestSnapshot;
  StreamSubscription<ProfileInteractionSnapshot>? _subscription;
  bool _isProcessingFollow = false;
  bool _isProcessingLike = false;
  bool _isLikedByViewer = false;
  bool? _pendingFollowTarget;
  bool? _pendingLikeTarget;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _viewerId = context.read<ProfileController>().profile.id;
    _profile = widget.initialProfile ?? _placeholderProfile(widget.profileId);
    final encounter = context
        .read<EncounterManager>()
        .findById('encounter_${widget.profileId}');
    _isLikedByViewer = encounter?.liked ?? false;
    _subscribeToStats();
    _loadDetails();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoadingDetails = true);
    final service = context.read<ProfileInteractionService>();
    try {
      final fresh = await service.loadProfile(widget.profileId);
      if (!mounted) return;
      if (fresh != null) {
        setState(() {
          _profile = _mergeProfileDetails(fresh);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  void _subscribeToStats() {
    final service = context.read<ProfileInteractionService>();
    _subscription = service
        .watchProfile(targetId: widget.profileId, viewerId: _viewerId)
        .listen(
      (snapshot) {
        _latestSnapshot = snapshot;
        if (!mounted) return;

        // For follow: only update if no pending operation OR server matches pending target
        bool shouldUpdateFollow = false;
        if (_pendingFollowTarget == null) {
          shouldUpdateFollow = true;
        } else if (snapshot.isFollowedByViewer == _pendingFollowTarget) {
          _pendingFollowTarget = null;
          shouldUpdateFollow = true;
        }
        // If pending doesn't match, keep local state

        // For like: only update if no pending operation OR server matches pending target
        bool shouldUpdateLike = false;
        if (_pendingLikeTarget == null) {
          shouldUpdateLike = true;
        } else if (snapshot.isLikedByViewer == _pendingLikeTarget) {
          _pendingLikeTarget = null;
          shouldUpdateLike = true;
        }
        // If pending doesn't match, keep local state

        setState(() {
          _profile = _profile.copyWith(
            followersCount: snapshot.followersCount,
            followingCount: snapshot.followingCount,
            receivedLikes: snapshot.receivedLikes,
            following: shouldUpdateFollow
                ? snapshot.isFollowedByViewer
                : _profile.following,
          );
          if (shouldUpdateLike) {
            _isLikedByViewer = snapshot.isLikedByViewer;
          }
        });
      },
      onError: (error, stackTrace) {
        debugPrint('Failed to watch profile ${widget.profileId}: $error');
      },
    );
  }

  Profile _mergeProfileDetails(Profile fresh) {
    final snapshot = _latestSnapshot;
    final snapshotFollow = snapshot?.isFollowedByViewer;
    final shouldHoldFollow = _pendingFollowTarget != null &&
        snapshotFollow != null &&
        snapshotFollow != _pendingFollowTarget;
    final resolvedReceivedLikes =
        snapshot?.receivedLikes ?? _profile.receivedLikes;
    final resolvedFollowers = snapshot?.followersCount ?? _profile.followersCount;
    final resolvedFollowing = snapshot?.followingCount ?? _profile.followingCount;
    return fresh.copyWith(
      followersCount: resolvedFollowers,
      followingCount: resolvedFollowing,
      receivedLikes: resolvedReceivedLikes,
      following: shouldHoldFollow
          ? _profile.following
          : (snapshotFollow ?? _profile.following),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isProcessingFollow || widget.profileId == _viewerId) {
      return;
    }
    final service = context.read<ProfileInteractionService>();
    final shouldFollow = !_profile.following;
    setState(() {
      _isProcessingFollow = true;
      _pendingFollowTarget = shouldFollow;
      final delta = shouldFollow ? 1 : -1;
      _profile = _profile.copyWith(
        following: shouldFollow,
        followersCount: (_profile.followersCount + delta).clamp(0, 999999),
      );
    });
    try {
      await service.setFollow(
        targetId: widget.profileId,
        viewerId: _viewerId,
        follow: shouldFollow,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final snapshot = _latestSnapshot;
        final fallbackCount =
            (_profile.followersCount + (shouldFollow ? -1 : 1))
                .clamp(0, 999999);
        _pendingFollowTarget = null;
        _profile = _profile.copyWith(
          following: snapshot?.isFollowedByViewer ?? !shouldFollow,
          followersCount: snapshot?.followersCount ?? fallbackCount,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('フォロー状態の更新に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingFollow = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isProcessingLike || widget.profileId == _viewerId) return;
    final service = context.read<ProfileInteractionService>();
    final viewerProfile = context.read<ProfileController>().profile;
    if (FirebaseAuth.instance.currentUser == null) {
      await ensureAnonymousAuth();
    }
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('認証に失敗したため、いいねできませんでした。')),
      );
      return;
    }
    final shouldLike = !_isLikedByViewer;
    setState(() {
      _isProcessingLike = true;
      _pendingLikeTarget = shouldLike;
      final delta = shouldLike ? 1 : -1;
      _isLikedByViewer = shouldLike;
      _profile = _profile.copyWith(
        receivedLikes: (_profile.receivedLikes + delta).clamp(0, 999999),
      );
    });
    try {
      await service.setLike(
        targetId: widget.profileId,
        viewerProfile: viewerProfile,
        like: shouldLike,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLikedByViewer = !_isLikedByViewer;
        _profile = _profile.copyWith(
          receivedLikes: (_profile.receivedLikes + (_isLikedByViewer ? 1 : -1))
              .clamp(0, 999999),
        );
        _pendingLikeTarget = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('いいねの更新に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingLike = false);
    }
  }

  void _showFollowSheet(ProfileFollowSheetMode mode) {
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ProfileFollowListSheet(
          targetId: widget.profileId,
          viewerId: _viewerId,
          mode: mode,
          onProfileTap: (profile) {
            if (profile.id == widget.profileId) {
              return;
            }
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ProfileViewScreen(
                  profileId: profile.id,
                  initialProfile: profile,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bio = _displayOrPlaceholder(_profile.bio);
    final homeTown = _displayOrPlaceholder(_profile.homeTown);
    final hashtags = _hashtagsOrPlaceholder(_profile.favoriteGames);
    final isSelf = widget.profileId == _viewerId;
    final timelineManager = context.watch<TimelineManager>();
    final profilePosts = timelineManager.posts
        .where((post) => post.authorId == _profile.id)
        .toList();
    final postLikesTotal = timelineManager.getPostLikesForUser(_profile.id);
    final totalLikes =
        (_profile.receivedLikes + postLikesTotal).clamp(0, 999999);
    final displayProfile =
        _profile.copyWith(receivedLikes: totalLikes);

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.displayName),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoadingDetails) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProfileAvatar(
                                profile: _profile,
                                radius: 38,
                                showBorder: false,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile.displayName,
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      bio == '未登録' ? '自己紹介はまだありません。' : bio,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ProfileStatsRow(
                            profile: displayProfile,
                            onFollowersTap: () => _showFollowSheet(
                                ProfileFollowSheetMode.followers),
                            onFollowingTap: () => _showFollowSheet(
                                ProfileFollowSheetMode.following),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'ステータス',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          ProfileInfoTile(
                            icon: Icons.mood,
                            title: '一言コメント',
                            value: bio,
                          ),
                          ProfileInfoTile(
                            icon: Icons.place_outlined,
                            title: '活動エリア',
                            value: homeTown,
                          ),
                          ProfileInfoTile(
                            icon: Icons.tag,
                            title: 'ハッシュタグ',
                            value: hashtags,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'タイムライン',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          _ProfileTimelineSection(
                            posts: profilePosts,
                            isSelf: isSelf,
                            timelineManager: timelineManager,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isSelf) ...[
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double width = constraints.maxWidth;
                        final bool compact = width < 360;
                        final double maxHeight = compact ? 58 : 68;
                        return Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: maxHeight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: LikeButton(
                                    variant: LikeButtonVariant.hero,
                                    isLiked: _isLikedByViewer,
                                    likeCount: totalLikes,
                                    onPressed: _toggleLike,
                                    maxHeight: maxHeight,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SizedBox(
                                height: maxHeight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: IgnorePointer(
                                    ignoring: _isProcessingFollow,
                                    child: Opacity(
                                      opacity: _isProcessingFollow ? 0.7 : 1,
                                      child: FollowButton(
                                        variant: LikeButtonVariant.hero,
                                        isFollowing: _profile.following,
                                        onPressed: _toggleFollow,
                                        maxHeight: maxHeight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Profile _placeholderProfile(String profileId) {
  return Profile(
    id: profileId,
    beaconId: profileId,
    displayName: '読み込み中...',
    bio: '読み込み中...',
    homeTown: '',
    favoriteGames: const [],
    avatarColor: Colors.blueGrey,
  );
}

String _formatTimelineTimestamp(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inHours < 1) return '${diff.inMinutes}\u5206\u524d';
  if (diff.inHours < 24) return '${diff.inHours}\u6642\u9593\u524d';
  return '${diff.inDays}\u65e5\u524d';
}

String _displayOrPlaceholder(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '未登録') {
    return '未登録';
  }
  return trimmed;
}

String _hashtagsOrPlaceholder(List<String> hashtags) {
  if (hashtags.isEmpty) {
    return '未登録';
  }
  return hashtags.join(' ');
}

class _ProfileTimelineSection extends StatelessWidget {
  const _ProfileTimelineSection({
    required this.posts,
    required this.isSelf,
    required this.timelineManager,
  });

  final List<TimelinePost> posts;
  final bool isSelf;
  final TimelineManager timelineManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (posts.isEmpty) {
      final message =
          isSelf ? 'まだタイムラインに投稿がありません。写真や気持ちをシェアするとここに表示されます。' : 'まだ投稿がありません。';
      return Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final visiblePosts = posts.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in visiblePosts)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ProfileTimelinePostCard(
              post: post,
              timelineManager: timelineManager,
            ),
          ),
        if (posts.length > visiblePosts.length)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '最新${visiblePosts.length}件を表示しています',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileTimelinePostCard extends StatelessWidget {
  const _ProfileTimelinePostCard({
    required this.post,
    required this.timelineManager,
  });

  final TimelinePost post;
  final TimelineManager timelineManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageBytes = post.decodeImage();
    final hasImageUrl = (post.imageUrl?.isNotEmpty ?? false);
    final likeLabel =
        post.likeCount > 0 ? '${post.likeCount}件のいいね' : 'まだいいねはありません';
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null || hasImageUrl)
            _ProfileTimelineImage(
              bytes: imageBytes,
              imageUrl: hasImageUrl ? post.imageUrl : null,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatTimelineTimestamp(post.createdAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'いいね',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        timelineManager.toggleLike(post.id);
                      },
                      icon: Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: post.isLiked
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${post.likeCount}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.caption,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                if (post.hashtags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final tag in post.hashtags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  likeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTimelineImage extends StatelessWidget {
  const _ProfileTimelineImage({this.bytes, this.imageUrl});

  final Uint8List? bytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 48,
        color: Colors.black38,
      ),
    );

    Widget buildImage() {
      if (bytes != null) {
        return Image.memory(
          bytes!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => placeholder,
        );
      }
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        return Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        );
      }
      return placeholder;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: buildImage(),
      ),
    );
  }
}
