import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/conversation.dart';
import '../models/profile.dart';
import '../services/firestore_dm_service.dart';
import '../services/profile_interaction_service.dart';
import '../state/profile_controller.dart';
import '../widgets/profile_avatar.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final FirestoreDmService _dmService = FirestoreDmService();
  StreamSubscription<List<Conversation>>? _subscription;
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  final Map<String, Profile?> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final userId = context.read<ProfileController>().profile.id;
    _subscription?.cancel();
    _subscription = _dmService.watchConversations(userId).listen(
      (conversations) {
        if (mounted) {
          setState(() {
            _conversations = conversations;
            _isLoading = false;
          });
        }
        // Prefetch profiles for participants
        for (final conv in conversations) {
          final otherId = conv.getOtherParticipantId(userId);
          if (!_profileCache.containsKey(otherId)) {
            _loadProfile(otherId);
          }
        }
      },
      onError: (error) {
        debugPrint('Error watching conversations: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadProfile(String profileId) async {
    final service = context.read<ProfileInteractionService>();
    try {
      final profile = await service.loadProfile(profileId);
      if (mounted && profile != null) {
        setState(() {
          _profileCache[profileId] = profile;
        });
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    // Simply restart the listener - Firestore will send fresh data
    _startListening();
    // Wait a bit for data to arrive
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _updateLocalPinState(
      String conversationId, String userId, bool isPinned) {
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index].pinnedBy[userId] = isPinned;
      }
    });
  }

  void _updateLocalMuteState(
      String conversationId, String userId, bool isMuted) {
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index].mutedBy[userId] = isMuted;
      }
    });
  }

  void _showConversationOptions(
    BuildContext context,
    Conversation conversation,
    String userId,
    Profile? profile,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isPinned = conversation.isPinnedFor(userId);
    final isMuted = conversation.isMutedFor(userId);
    final displayName = profile?.displayName ?? l10n?.chatPartner ?? '相手';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    if (profile != null)
                      ProfileAvatar(profile: profile, radius: 24)
                    else
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.person, color: Colors.grey[400]),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Options
              _buildOptionTile(
                icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                iconColor:
                    isPinned ? theme.colorScheme.primary : Colors.grey[700]!,
                label: isPinned
                    ? (l10n?.unpin ?? 'ピン留めを解除')
                    : (l10n?.pin ?? 'ピン留め'),
                onTap: () async {
                  Navigator.pop(context);
                  // Optimistic update
                  _updateLocalPinState(conversation.id, userId, !isPinned);
                  await _dmService.togglePin(
                    conversationId: conversation.id,
                    userId: userId,
                    isPinned: !isPinned,
                  );
                },
              ),
              _buildOptionTile(
                icon: isMuted
                    ? Icons.notifications_off
                    : Icons.notifications_off_outlined,
                iconColor: isMuted ? Colors.orange : Colors.grey[700]!,
                label: isMuted
                    ? (l10n?.unmute ?? 'ミュート解除')
                    : (l10n?.muteNotifications ?? '通知をミュート'),
                onTap: () async {
                  Navigator.pop(context);
                  // Optimistic update
                  _updateLocalMuteState(conversation.id, userId, !isMuted);
                  await _dmService.toggleMute(
                    conversationId: conversation.id,
                    userId: userId,
                    isMuted: !isMuted,
                  );
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                label: l10n?.deleteConversation ?? '会話を削除',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, conversation, displayName);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(
      BuildContext context, Conversation conversation, String displayName) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteConversation ?? '会話を削除'),
        content: Text(l10n?.deleteConversationConfirm(displayName) ??
            '$displayNameとの会話を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.cancel ?? 'キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Optimistic local deletion - remove from list immediately
              setState(() {
                _conversations.removeWhere((c) => c.id == conversation.id);
              });
              // Then delete from Firestore
              await _dmService.deleteConversation(conversation.id);
            },
            child: Text(
              l10n?.delete ?? '削除',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.watch<ProfileController>().profile.id;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          l10n?.messagesTitle ?? 'メッセージ',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
            )
          : _conversations.isEmpty
              ? _buildEmptyState(theme)
              : _buildConversationList(theme, userId),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: theme.colorScheme.primary,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mark_chat_unread_rounded,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizations.of(context)?.noMessages ??
                          'メッセージはまだありません',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)?.startConversationHint ??
                          'すれ違ったユーザーと\n会話を始めてみましょう',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(ThemeData theme, String userId) {
    // Sort conversations: pinned first, then by lastMessageAt
    final sorted = List<Conversation>.from(_conversations);
    sorted.sort((a, b) {
      final aPinned = a.isPinnedFor(userId);
      final bPinned = b.isPinnedFor(userId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      // Both same pin status, sort by date
      final aTime = a.lastMessageAt ?? DateTime(1970);
      final bTime = b.lastMessageAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    final pinnedConversations =
        sorted.where((c) => c.isPinnedFor(userId)).toList();
    final regularConversations =
        sorted.where((c) => !c.isPinnedFor(userId)).toList();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: theme.colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          // Pinned section
          if (pinnedConversations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.push_pin, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)?.pin ?? 'ピン留め',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...pinnedConversations.map((conversation) =>
                _buildConversationItem(context, theme, userId, conversation)),
            if (regularConversations.isNotEmpty) const SizedBox(height: 16),
          ],
          // Regular conversations
          ...regularConversations.map((conversation) =>
              _buildConversationItem(context, theme, userId, conversation)),
        ],
      ),
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    ThemeData theme,
    String userId,
    Conversation conversation,
  ) {
    final otherId = conversation.getOtherParticipantId(userId);
    final profile = _profileCache[otherId];
    final unreadCount = conversation.getUnreadCount(userId);
    final isMuted = conversation.isMutedFor(userId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _VibCardConversationTile(
        conversation: conversation,
        profile: profile,
        unreadCount: unreadCount,
        isMuted: isMuted,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversation.id,
                otherProfile: profile,
              ),
            ),
          );
        },
        onLongPress: () {
          _showConversationOptions(context, conversation, userId, profile);
        },
      ),
    );
  }
}

class _VibCardConversationTile extends StatelessWidget {
  const _VibCardConversationTile({
    required this.conversation,
    required this.profile,
    required this.unreadCount,
    required this.isMuted,
    required this.onTap,
    required this.onLongPress,
  });

  final Conversation conversation;
  final Profile? profile;
  final int unreadCount;
  final bool isMuted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profile?.displayName ??
        AppLocalizations.of(context)?.loading ??
        '読み込み中...';
    final lastMessage = conversation.lastMessage ?? '';
    final lastMessageAt = conversation.lastMessageAt;
    final hasUnread = unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: hasUnread
            ? const Color(0xFFFFFDE7)
            : Colors.white, // Light yellow for unread
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(hasUnread ? 0.04 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: hasUnread
            ? Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.black.withOpacity(0.04),
          highlightColor: Colors.black.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar with unread indicator
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasUnread
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: profile != null
                          ? ProfileAvatar(profile: profile!, radius: 28)
                          : CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[100],
                              child:
                                  Icon(Icons.person, color: Colors.grey[400]),
                            ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.mark_email_unread,
                              size: 8,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: hasUnread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 17,
                                      color: Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMuted) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.notifications_off,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (lastMessageAt != null)
                            Text(
                              _formatTime(context, lastMessageAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: hasUnread
                                    ? theme.colorScheme.primary
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty
                                  ? (AppLocalizations.of(context)?.noMessages ??
                                      'メッセージはまだありません')
                                  : lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: hasUnread
                                    ? Colors.black87
                                    : Colors.grey[500],
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(minWidth: 28),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  height: 1,
                                ),
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
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(time);
    final isSameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;

    if (diff.inMinutes < 1) return l10n?.now ?? '今';
    if (diff.inHours < 1)
      return l10n?.minutesAgo(diff.inMinutes) ?? '${diff.inMinutes}分前';
    if (isSameDay)
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays < 7)
      return l10n?.daysAgo(diff.inDays) ?? '${diff.inDays}日前';
    return '${time.month}/${time.day}';
  }
}
