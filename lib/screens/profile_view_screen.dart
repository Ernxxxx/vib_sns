import 'dart:async';
import 'dart:convert';
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
    final resolvedFollowers =
        snapshot?.followersCount ?? _profile.followersCount;
    final resolvedFollowing =
        snapshot?.followingCount ?? _profile.followingCount;
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
    final displayProfile = _profile.copyWith(receivedLikes: totalLikes);

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
                          _ProfileTimelineTabs(
                            posts: profilePosts,
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

class _ProfileTimelineTabs extends StatefulWidget {
  const _ProfileTimelineTabs({
    required this.posts,
    required this.timelineManager,
  });

  final List<TimelinePost> posts;
  final TimelineManager timelineManager;

  @override
  State<_ProfileTimelineTabs> createState() => _ProfileTimelineTabsState();
}

class _ProfileTimelineTabsState extends State<_ProfileTimelineTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaPosts = widget.posts
        .where(
            (p) => p.imageBase64 != null || (p.imageUrl?.isNotEmpty ?? false))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(text: '投稿'),
            Tab(text: 'メディア'),
          ],
        ),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              // 投稿タブ
              _PostsTab(
                posts: widget.posts,
                timelineManager: widget.timelineManager,
              ),
              // メディアタブ
              _MediaTab(posts: mediaPosts),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.posts,
    required this.timelineManager,
  });

  final List<TimelinePost> posts;
  final TimelineManager timelineManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'まだ投稿がありません',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _ProfilePostCard(
          post: post,
          timelineManager: timelineManager,
        );
      },
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.posts});

  final List<TimelinePost> posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'メディアがありません',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _MediaThumbnail(post: post);
      },
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.post});

  final TimelinePost post;

  @override
  Widget build(BuildContext context) {
    final imageBytes = post.decodeImage();
    final hasImageUrl = post.imageUrl?.isNotEmpty ?? false;

    Widget buildImage() {
      if (imageBytes != null) {
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      }
      if (hasImageUrl) {
        return Image.network(
          post.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      }
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image, color: Colors.grey),
      );
    }

    return buildImage();
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.timelineManager,
  });

  final TimelinePost post;
  final TimelineManager timelineManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewerId = context.watch<ProfileController>().profile.id;
    final canDelete = post.authorId.isEmpty ||
        post.authorId == viewerId ||
        post.authorId == 'local';
    final imageBytes = post.decodeImage();
    final hasImageUrl = post.imageUrl?.isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター
              _buildAvatar(theme),
              const SizedBox(width: 12),
              // コンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー: ユーザー名 + 時間 + メニュー
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.authorName.isEmpty ? '匿名' : post.authorName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimelineTimestamp(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _confirmDelete(context);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('削除'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    // 本文
                    if (post.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          post.caption,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    // ハッシュタグ
                    if (post.hashtags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tag in post.hashtags)
                              Text(
                                tag.startsWith('#') ? tag : '#$tag',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    // 画像
                    if (imageBytes != null || hasImageUrl)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImage(imageBytes, hasImageUrl),
                        ),
                      ),
                    // アクション
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => timelineManager.toggleLike(post.id),
                          child: Icon(
                            post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 22,
                            color: post.isLiked
                                ? Colors.red
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (post.likeCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${post.likeCount}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    MemoryImage? avatarImage;
    if (post.authorAvatarImageBase64 != null &&
        post.authorAvatarImageBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(post.authorAvatarImageBase64!.trim());
        if (bytes.isNotEmpty) {
          avatarImage = MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final trimmedName =
        post.authorName.trim().isEmpty ? '匿名' : post.authorName.trim();
    final initial = trimmedName.characters.first.toUpperCase();

    return CircleAvatar(
      radius: 20,
      backgroundColor: post.authorColor,
      foregroundImage: avatarImage,
      child: avatarImage == null
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('投稿を削除'),
          content: const Text('この投稿を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    try {
      await timelineManager.deletePost(post);
      messenger.showSnackBar(
        const SnackBar(content: Text('投稿を削除しました。')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
  }

  Widget _buildImage(Uint8List? imageBytes, bool hasImageUrl) {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    if (hasImageUrl) {
      return Image.network(
        post.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}
