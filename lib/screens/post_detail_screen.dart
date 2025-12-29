import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../models/timeline_post.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import '../widgets/full_screen_image_viewer.dart';
import 'profile_view_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
  });

  final TimelinePost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _replyController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  TimelinePost? _replyingTo;

  @override
  void dispose() {
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setReplyingTo(TimelinePost? reply) {
    setState(() => _replyingTo = reply);
    _focusNode.requestFocus();
  }

  void _clearReplyingTo() {
    setState(() => _replyingTo = null);
  }

  Future<void> _sendReply() async {
    final caption = _replyController.text.trim();
    if (caption.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await context.read<TimelineManager>().addReply(
            parentPostId: widget.post.id,
            caption: caption,
            replyToId: _replyingTo?.id,
            replyToAuthorName: _replyingTo?.authorName,
          );
      _replyController.clear();
      _clearReplyingTo();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リプライの送信に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewerId = context.watch<ProfileController>().profile.id;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('投稿'),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostCard(post: widget.post, viewerId: viewerId),
                  const Divider(height: 1),
                  StreamBuilder<List<TimelinePost>>(
                    stream: context
                        .read<TimelineManager>()
                        .watchReplies(widget.post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final replies = snapshot.data ?? [];
                      if (replies.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48,
                                    color: Colors.grey.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'まだリプライがありません',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // リプライのツリー構築
                      final rootReplies = <TimelinePost>[];
                      final replyMap = <String, List<TimelinePost>>{};
                      final idMap = {for (var r in replies) r.id: r};

                      for (var reply in replies) {
                        if (reply.replyToId == null ||
                            !idMap.containsKey(reply.replyToId)) {
                          rootReplies.add(reply);
                        } else {
                          final parentId = reply.replyToId!;
                          if (!replyMap.containsKey(parentId)) {
                            replyMap[parentId] = [];
                          }
                          replyMap[parentId]!.add(reply);
                        }
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rootReplies.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final rootReply = rootReplies[index];
                          return _ReplyItem(
                            reply: rootReply,
                            parentPostId: widget.post.id,
                            postAuthorId: widget.post.authorId,
                            viewerId: viewerId,
                            onReply: (target) => _setReplyingTo(target),
                            replyMap: replyMap,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _ReplyComposer(
            controller: _replyController,
            focusNode: _focusNode,
            isSending: _isSending,
            onSend: _sendReply,
            replyingTo: _replyingTo,
            onCancelReply: _clearReplyingTo,
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.viewerId,
  });

  final TimelinePost post;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TimelineManagerを監視して最新の投稿状態を取得
    final timelineManager = context.watch<TimelineManager>();
    final currentPost = timelineManager.posts.firstWhere(
      (p) => p.id == post.id,
      orElse: () => post,
    );
    final avatarImage = currentPost.resolveAvatarImage();

    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(context),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey,
                  foregroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (post.formattedAuthorUsername != null)
                        Text(
                          post.formattedAuthorUsername!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.caption,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          // ハッシュタグ
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
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
          ],
          if (post.imageBase64 != null || post.imageUrl != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => FullScreenImageViewer.show(
                context,
                imageBytes: post.decodeImage(),
                imageUrl: post.imageUrl,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImage(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _formatFullDate(post.createdAt),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionItem(
                icon: currentPost.isLiked
                    ? Icons.favorite
                    : Icons.favorite_border,
                label: '${currentPost.likeCount}',
                color: currentPost.isLiked ? Colors.pink : null,
                onTap: () {
                  context.read<TimelineManager>().toggleLike(currentPost.id);
                },
              ),
              const SizedBox(width: 24),
              _ActionItem(
                icon: Icons.chat_bubble_outline,
                label: '${currentPost.replyCount}',
                onTap: () {}, // 既に詳細画面なので何もしない
              ),
              const Spacer(),
              if (post.authorId == viewerId)
                GestureDetector(
                  onTap: () => _deletePost(context),
                  child: Icon(
                    Icons.delete_outline,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imageBytes = post.decodeImage();
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return Image.network(
        post.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  void _openProfile(BuildContext context) {
    if (post.authorId.isEmpty || post.authorId.startsWith('bot_')) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileViewScreen(
          profileId: post.authorId,
          initialProfile: Profile(
            id: post.authorId,
            beaconId: post.authorId,
            displayName: post.authorName,
            username: post.authorUsername,
            bio: '',
            homeTown: '',
            favoriteGames: const [],
            avatarColor: post.authorColor,
            avatarImageBase64: post.authorAvatarImageBase64,
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<TimelineManager>().deletePost(post);
      if (context.mounted) {
        Navigator.of(context).pop(); // 詳細画面を閉じる
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = color ?? theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 22, color: contentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: contentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyItem extends StatefulWidget {
  const _ReplyItem({
    required this.reply,
    required this.parentPostId,
    required this.postAuthorId,
    required this.viewerId,
    required this.onReply,
    required this.replyMap,
  });

  final TimelinePost reply;
  final String parentPostId;
  final String postAuthorId;
  final String viewerId;
  final Function(TimelinePost) onReply;
  final Map<String, List<TimelinePost>> replyMap;

  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // 自身が投稿者本人、または子孫リプライに投稿者本人のリプライが含まれている場合は展開
    if (widget.reply.authorId == widget.postAuthorId ||
        _hasAuthorReplyInDescendants(widget.reply.id)) {
      _isExpanded = true;
    }
  }

  bool _hasAuthorReplyInDescendants(String replyId) {
    final children = widget.replyMap[replyId] ?? [];
    for (final child in children) {
      if (child.authorId == widget.postAuthorId) return true;
      if (_hasAuthorReplyInDescendants(child.id)) return true;
    }
    return false;
  }

  void _openProfile(BuildContext context, String authorId) {
    if (authorId.isEmpty || authorId.startsWith('bot_')) return;
    // リプライの著者の詳細情報はここには完全にはないため、簡易的なProfileオブジェクトを作成するか、
    // IDだけ渡してProfileViewScreen側でフェッチさせる。
    // ここではreplyオブジェクトから復元できる情報のみ渡す。
    // しかし、_ReplyItemはTimelinePostを持っているので、そこから取得可能。

    // authorIdがwidget.reply.authorIdと異なる場合（子リプライの再帰呼び出しなど）もあるが、
    // このメソッドは引数でauthorIdを受け取るようにしている。
    // ただし、このメソッド呼び出し元は自分のアバタータップなので widget.reply.authorId と一致するはず。

    // 簡易実装として、widget.replyの情報を使う
    final profile = Profile(
      id: widget.reply.authorId,
      beaconId: widget.reply.authorId,
      displayName: widget.reply.authorName,
      username: widget.reply.authorUsername,
      bio: '',
      homeTown: '',
      favoriteGames: const [],
      avatarColor: widget.reply.authorColor,
      avatarImageBase64: widget.reply.authorAvatarImageBase64,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileViewScreen(
          profileId: authorId,
          initialProfile: profile,
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    try {
      await context.read<TimelineManager>().toggleReplyLike(
            parentPostId: widget.parentPostId,
            replyId: widget.reply.id,
          );
      // ローカル更新はStream経由で行われるためsetState不要だが、即時反映のためにやってもよい。
      // ただしTimelineManagerがnotifyListenersすればStreamBuilderが再構築される。
    } catch (error) {
      // エラー処理
    }
  }

  Future<void> _deleteReply(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('リプライを削除'),
        content: const Text('このリプライを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<TimelineManager>().deleteReply(
            parentPostId: widget.parentPostId,
            replyId: widget.reply.id,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarImage = widget.reply.resolveAvatarImage();
    final childReplies = widget.replyMap[widget.reply.id] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openProfile(context, widget.reply.authorId),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  foregroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                _openProfile(context, widget.reply.authorId),
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodyMedium,
                                children: [
                                  TextSpan(
                                    text: widget.reply.authorName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (widget.reply.formattedAuthorUsername !=
                                      null)
                                    TextSpan(
                                      text:
                                          ' ${widget.reply.formattedAuthorUsername}',
                                      style: TextStyle(
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(widget.reply.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 返信先表示
                    if (widget.reply.replyToAuthorName != null &&
                        widget.reply.replyToId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Text('Replying to ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text('@${widget.reply.replyToAuthorName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),

                    Text(
                      widget.reply.caption,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ReplyAction(
                          icon: widget.reply.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: '${widget.reply.likeCount}',
                          color: widget.reply.isLiked ? Colors.pink : null,
                          onTap: _toggleLike,
                        ),
                        const SizedBox(width: 20),
                        _ReplyAction(
                          icon: Icons.chat_bubble_outline,
                          label: '',
                          onTap: () => widget.onReply(widget.reply),
                        ),
                        const Spacer(),
                        if (widget.reply.authorId == widget.viewerId)
                          GestureDetector(
                            onTap: () => _deleteReply(context),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 子リプライがある場合
          if (childReplies.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (!_isExpanded)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 24,
                          height: 1,
                          color: theme.colorScheme.outlineVariant),
                      const SizedBox(width: 8),
                      Text(
                        '返信${childReplies.length}件を表示',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 36, top: 8),
                child: Column(
                  children: childReplies.map((childReply) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: _ReplyItem(
                        reply: childReply,
                        parentPostId: widget.parentPostId,
                        postAuthorId: widget.postAuthorId,
                        viewerId: widget.viewerId,
                        onReply: widget.onReply,
                        replyMap: widget.replyMap,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReplyAction extends StatelessWidget {
  const _ReplyAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: color ?? theme.colorScheme.onSurfaceVariant),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: color ?? theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    this.replyingTo,
    this.onCancelReply,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final TimelinePost? replyingTo;
  final VoidCallback? onCancelReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reply to ${replyingTo!.authorName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: Icon(Icons.close,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'リプライを投稿する',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.arrow_upward, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inHours < 1) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  return '${diff.inDays}日前';
}

String _formatFullDate(DateTime time) {
  return '${time.year}/${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}
