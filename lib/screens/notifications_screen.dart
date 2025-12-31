import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../state/encounter_manager.dart';
import '../state/notification_manager.dart';
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
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationTile(notification: notification);
                },
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: theme.cardColor,
        elevation: isUnread ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isUnread
              ? BorderSide(color: typeColor.withOpacity(0.5), width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationIcon(
                  notification: notification,
                  typeColor: typeColor,
                  iconData: _getNotificationIconData(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getNotificationHeader(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (notification.message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 8),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getNotificationHeader() {
    switch (notification.type) {
      case AppNotificationType.like:
      case AppNotificationType.timelineLike:
        return 'NEW LIKE';
      case AppNotificationType.reply:
        return 'NEW REPLY';
      case AppNotificationType.follow:
        return 'NEW PROVIDER';
      case AppNotificationType.encounter:
        return 'STREETPASS';
    }
  }

  void _handleTap(BuildContext context) {
    final manager = context.read<NotificationManager>();
    switch (notification.type) {
      case AppNotificationType.encounter:
        if (notification.encounterId != null) {
          manager.markEncounterNotificationsRead(notification.encounterId!);
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
          manager.markNotificationRead(notification.id);
        }
        break;
      case AppNotificationType.like:
      case AppNotificationType.follow:
      case AppNotificationType.timelineLike:
        manager.markNotificationRead(notification.id);
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
      case AppNotificationType.reply:
        manager.markNotificationRead(notification.id);
        if (notification.postId != null) {
          final timelineManager = context.read<TimelineManager>();
          try {
            final post = timelineManager.posts.firstWhere(
              (p) => p.id == notification.postId,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(post: post),
              ),
            );
          } catch (e) {
            // Post not found
          }
        }
        break;
    }
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.notification,
    required this.typeColor,
    required this.iconData,
  });

  final AppNotification notification;
  final Color typeColor;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    final profile = notification.profile;

    Widget mainAvatar;
    if (profile != null) {
      ImageProvider? imageProvider;
      if (profile.avatarImageBase64 != null &&
          profile.avatarImageBase64!.isNotEmpty) {
        try {
          // データURLスキームの処理は省略されていますが、
          // 実際にはここのロジックは既存のものを使えばOK
          final uri = Uri.parse(profile.avatarImageBase64!);
          if (uri.data != null) {
            imageProvider = MemoryImage(uri.data!.contentAsBytes());
          }
        } catch (_) {}
      }

      mainAvatar = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: imageProvider,
        child: imageProvider == null
            ? const Icon(Icons.person, color: Colors.grey)
            : null,
      );
    } else {
      mainAvatar = CircleAvatar(
        radius: 24,
        backgroundColor: typeColor.withOpacity(0.1),
        child: Icon(iconData, color: typeColor, size: 24),
      );
    }

    if (profile == null) return mainAvatar;

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
