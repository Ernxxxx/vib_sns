import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../state/encounter_manager.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import '../widgets/app_logo.dart';
import 'post_detail_screen.dart';
import 'profile_view_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NotificationManager>();
    final notifications = manager.notifications;
    final hasUnread = manager.unreadCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '\u5168\u4ef6\u3092\u65e2\u8aad\u306b\u3059\u308b',
            onPressed: hasUnread ? manager.markAllRead : null,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NotificationManager>().refresh(),
        child: notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  const _EmptyNotificationsView(),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationTile(notification: notification);
                },
              ),
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  final TextEditingController _replyController = TextEditingController();

  AppNotification get notification => widget.notification;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Color _getNotificationColor(ThemeData theme) {
    switch (notification.type) {
      case AppNotificationType.like:
      case AppNotificationType.timelineLike:
        return Colors.pinkAccent;
      case AppNotificationType.reply:
        return Colors.green;
      case AppNotificationType.follow:
        return Colors.blueAccent;
      case AppNotificationType.encounter:
        return Colors.purpleAccent;
    }
  }

  IconData _getNotificationIconData() {
    switch (notification.type) {
      case AppNotificationType.like:
      case AppNotificationType.timelineLike:
        return Icons.favorite;
      case AppNotificationType.reply:
        return Icons.chat_bubble;
      case AppNotificationType.follow:
        return Icons.person_add;
      case AppNotificationType.encounter:
        return Icons.sensors;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.read;
    final typeColor = _getNotificationColor(theme);

    // リプライ通知とそれ以外でレイアウトを分ける
    final isReply = notification.type == AppNotificationType.reply;

    return Material(
        color: isUnread
            ? typeColor.withOpacity(0.05)
            : theme.scaffoldBackgroundColor,
        child: InkWell(
          onTap: () => _handleTap(context),
          splashColor: theme.colorScheme.onSurface.withOpacity(0.1),
          highlightColor: theme.colorScheme.onSurface.withOpacity(0.05),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側：アイコンエリア
                if (isReply) ...[
                  // リプライの場合はアバターのみ（バッジなしでシンプルに）
                  _NotificationIcon(
                    notification: notification,
                    typeColor: typeColor,
                    iconData: _getNotificationIconData(),
                  ),
                ] else ...[
                  // その他の場合はアクションアイコンまたはアバター＋バッジ
                  // 画像のスタイル（左にアクションアイコン）に近づけるため
                  // ここでは既存の「アバター＋右下バッジ」を維持しつつ、少しサイズ感を調整
                  _NotificationIcon(
                    notification: notification,
                    typeColor: typeColor,
                    iconData: _getNotificationIconData(),
                  ),
                ],
                const SizedBox(width: 12),
                // 右側：コンテンツエリア
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ヘッダー（名前・ID・時間）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    notification.profile?.displayName ??
                                        'Unknown',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (notification.profile?.username != null) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '@${notification.profile!.username}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 時間表示（右端）
                          Text(
                            _relativeTime(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // 本文またはアクションテキスト
                      if (isReply) ...[
                        // リプライ本文
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 1.4,
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // アクションボタン（枠線なし、アイコンのみ）
                        _buildReplyActions(context, theme),
                      ] else ...[
                        // その他の通知テキスト
                        _buildNotificationContent(context, theme, typeColor),
                      ],
                    ],
                  ),
                ),
                // 未読インジケータ（右端中央などは邪魔なので、背景色で表現済みだが念のためドットも残すか？
                // 画像のようにシンプルにするならドットは不要かも。背景色で十分。
                // 一応、未読の場合は右上に小さなドットを表示
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ));
  }

  // リプライ用のアクションボタン群
  Widget _buildReplyActions(BuildContext context, ThemeData theme) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('timelinePosts')
          .doc(notification.postId)
          .collection('replies')
          .doc(notification.replyId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final likeCount = data['likeCount'] as int? ?? 0;
        final replyCount = data['replyCount'] as int? ?? 0;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final viewerId = context.read<ProfileController>().profile.id;
        final isLiked = likedBy.contains(viewerId);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // いいねボタン（左）
            InkWell(
              onTap: () {
                _markAsRead();
                _handleReplyLike(context, isLiked);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isLiked
                          ? Colors.pink
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$likeCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: likeCount > 0
                            ? (isLiked
                                ? Colors.pink
                                : theme.colorScheme.onSurfaceVariant)
                            : Colors.transparent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 返信ボタン（右）
            InkWell(
              onTap: () {
                _markAsRead();
                _showReplySheet(context);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$replyCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: replyCount > 0
                            ? theme.colorScheme.onSurfaceVariant
                            : Colors.transparent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // スペーサー（右側を空けるため）
            const Spacer(flex: 3),
          ],
        );
      },
    );
  }

  void _markAsRead() {
    if (!notification.read) {
      context.read<NotificationManager>().markNotificationRead(notification.id);
    }
  }

  Widget _buildNotificationContent(
      BuildContext context, ThemeData theme, Color typeColor) {
    if (notification.type == AppNotificationType.reply) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.title,
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (notification.postId != null &&
                  notification.replyId != null) ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('timelinePosts')
                      .doc(notification.postId)
                      .collection('replies')
                      .doc(notification.replyId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data =
                        snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final likeCount = data['likeCount'] as int? ?? 0;
                    final likedBy = List<String>.from(data['likedBy'] ?? []);
                    final viewerId =
                        context.read<ProfileController>().profile.id;
                    final isLiked = likedBy.contains(viewerId);

                    return InkWell(
                      onTap: () => _handleReplyLike(context, isLiked),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLiked
                              ? Colors.pink.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLiked
                                ? Colors.pink.withOpacity(0.5)
                                : theme.dividerColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isLiked
                                  ? Colors.pink
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$likeCount',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isLiked
                                    ? Colors.pink
                                    : theme.colorScheme.onSurfaceVariant
                                        .withOpacity(likeCount > 0 ? 1.0 : 0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
              ],
              InkWell(
                onTap: () => _showReplySheet(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    String actionText;
    IconData? actionIcon;

    switch (notification.type) {
      case AppNotificationType.like:
        actionText = 'あなたにいいねしました';
        actionIcon = Icons.favorite;
        break;
      case AppNotificationType.timelineLike:
        actionText = 'あなたの投稿にいいねしました';
        actionIcon = Icons.favorite;
        break;
      case AppNotificationType.follow:
        actionText = 'あなたをフォローしました';
        actionIcon = Icons.person_add;
        break;
      case AppNotificationType.encounter:
        actionText = notification.message.isEmpty
            ? 'すれちがいが発生しました！'
            : notification.message;
        actionIcon = Icons.sensors;
        break;
      default:
        actionText = notification.message;
        actionIcon = null;
    }

    // すれ違いの場合はメッセージがあればそれを表示
    if (notification.type == AppNotificationType.encounter &&
        notification.message.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(actionIcon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                actionText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            notification.message,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Row(
      children: [
        if (actionIcon != null) ...[
          Icon(actionIcon, size: 14, color: typeColor.withOpacity(0.8)),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            actionText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final notificationManager = context.read<NotificationManager>();

    if (notification.type == AppNotificationType.reply) {
      // リプライの本文や余白をタップした時も投稿詳細へ
      if (notification.postId != null) {
        final timelineManager = context.read<TimelineManager>();
        final post = await timelineManager.getPost(notification.postId!);

        if (post != null && context.mounted) {
          notificationManager.markNotificationRead(notification.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: post),
            ),
          );
        }
      }
      return;
    }

    switch (notification.type) {
      case AppNotificationType.encounter:
        if (notification.encounterId != null) {
          notificationManager
              .markEncounterNotificationsRead(notification.encounterId!);
          final encounter = context
              .read<EncounterManager>()
              .findById(notification.encounterId!);
          if (encounter == null) {
            return;
          }
          context.read<EncounterManager>().markSeen(encounter.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                profileId: encounter.profile.id,
                initialProfile: encounter.profile,
              ),
            ),
          );
        } else {
          notificationManager.markNotificationRead(notification.id);
        }
        break;
      case AppNotificationType.follow:
        notificationManager.markNotificationRead(notification.id);
        if (notification.profile != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                profileId: notification.profile!.id,
                initialProfile: notification.profile!,
              ),
            ),
          );
        }
        break;
      case AppNotificationType.like:
        notificationManager.markNotificationRead(notification.id);
        if (notification.profile != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                profileId: notification.profile!.id,
                initialProfile: notification.profile!,
              ),
            ),
          );
        }
        break;
      case AppNotificationType.timelineLike:
        if (notification.postId != null) {
          final timelineManager = context.read<TimelineManager>();
          final post = await timelineManager.getPost(notification.postId!);

          if (post != null && context.mounted) {
            notificationManager.markNotificationRead(notification.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(post: post),
              ),
            );
          }
        } else {
          notificationManager.markNotificationRead(notification.id);
        }
        break;
      default:
        break;
    }
  }

  void _handleReplyLike(BuildContext context, bool isLiked) {
    if (notification.postId == null || notification.replyId == null) return;

    // StreamBuilderが更新を検知するのでsetState不要
    context.read<TimelineManager>().toggleReplyLike(
          parentPostId: notification.postId!,
          replyId: notification.replyId!,
        );
  }

  void _showReplySheet(BuildContext context) {
    _replyController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: MediaQuery.of(sheetContext).viewInsets,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.reply, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${notification.profile?.displayName ?? "ユーザー"}への返信',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 元のリプライ内容（引用）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  notification.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _replyController,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                maxLength: 140,
                decoration: InputDecoration(
                  hintText: '返信を入力...',
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final caption = _replyController.text.trim();
                      if (caption.isEmpty) return;

                      Navigator.pop(sheetContext);

                      if (notification.postId != null) {
                        try {
                          await context.read<TimelineManager>().addReply(
                                parentPostId: notification.postId!,
                                caption: caption,
                                replyToId: notification.replyId,
                                replyToAuthorName:
                                    notification.profile?.displayName,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('返信しました'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('エラーが発生しました: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('送信'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.notification,
    required this.typeColor,
    required this.iconData,
    this.showBadge = true,
  });

  final AppNotification notification;
  final Color typeColor;
  final IconData iconData;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final profile = notification.profile;

    Widget mainAvatar;
    if (profile != null) {
      ImageProvider? imageProvider;
      final imageBase64 = profile.avatarImageBase64?.trim();
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        try {
          // data: URL形式かraw base64のどちらにも対応
          if (imageBase64.startsWith('data:')) {
            final uri = Uri.parse(imageBase64);
            if (uri.data != null) {
              imageProvider = MemoryImage(uri.data!.contentAsBytes());
            }
          } else {
            // ProfileAvatarと同じ方式でbase64デコード
            final bytes = base64Decode(imageBase64);
            if (bytes.isNotEmpty) {
              imageProvider = MemoryImage(bytes);
            }
          }
        } catch (_) {}
      }

      mainAvatar = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.person, color: Colors.white, size: 28.8)
            : null,
      );
    } else {
      mainAvatar = CircleAvatar(
        radius: 24,
        backgroundColor: typeColor.withOpacity(0.1),
        child: Icon(iconData, color: typeColor, size: 24),
      );
    }

    if (profile == null || !showBadge) return mainAvatar;

    return Stack(
      children: [
        mainAvatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: typeColor,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
            child: Icon(
              iconData,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none,
                size: 72, color: Color(0xFFFFC400)),
            const SizedBox(height: 18),
            Text(
              '\u307e\u3060\u901a\u77e5\u304c\u3042\u308a\u307e\u305b\u3093\u3002\n\u3059\u308c\u9055\u3044\u3084\u30a4\u30f3\u30bf\u30fc\u30af\u30b7\u30e7\u30f3\u3092\u307e\u3064\u308a\u307e\u3057\u3087\u3046\u3002',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '\u305f\u3063\u305f\u4eca';
  if (diff.inHours < 1) return '${diff.inMinutes}\u5206\u524d';
  if (diff.inHours < 24) return '${diff.inHours}\u6642\u9593\u524d';
  return '${diff.inDays}\u65e5\u524d';
}
