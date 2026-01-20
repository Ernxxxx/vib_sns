import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_dm_service.dart';

import 'encounter_list_screen.dart';
import 'conversation_list_screen.dart';
import 'notifications_screen.dart';

import '../services/streetpass_service.dart';
import '../services/profile_interaction_service.dart';
import '../state/encounter_manager.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';
import '../models/profile.dart';
import '../models/encounter.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../utils/color_extensions.dart';
import 'package:vib_sns/models/timeline_post.dart';
import '../widgets/app_logo.dart';
import '../widgets/hashtag_picker.dart';
import '../widgets/profile_avatar.dart';
import '../utils/app_text_styles.dart';
import '../widgets/profile_info_tile.dart';
import '../widgets/profile_stats_row.dart';
import 'profile_follow_list_sheet.dart';
import 'profile_view_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';
import '../services/fcm_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _autoStartAttempted = false;
  final GlobalKey<_TimelineScreenState> _timelineKey =
      GlobalKey<_TimelineScreenState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _TimelineScreen(key: _timelineKey),
      const SizedBox.shrink(),
      const NotificationsScreen(),
      const _ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoStartStreetPass();
      _setupFCMHandlers();
    });
  }

  /// FCM通知タップ時のハンドラを設定
  Future<void> _setupFCMHandlers() async {
    // 終了状態から起動した場合の初期メッセージを処理
    final initialData = await FCMService.getInitialMessage();
    if (initialData != null && mounted) {
      _handleFCMNavigation(initialData);
    }

    // バックグラウンドから復帰した場合のハンドラを設定
    FCMService.setupInteractionHandler((data) {
      if (mounted) {
        _handleFCMNavigation(data);
      }
    });
  }

  /// FCM通知データに基づいて画面遷移を実行
  void _handleFCMNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'follow':
      case 'like':
        final profileId = data['profileId'] as String?;
        if (profileId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(profileId: profileId),
            ),
          );
        }
        break;

      case 'timelineLike':
      case 'reply':
        final postId = data['postId'] as String?;
        if (postId != null) {
          _navigateToPost(postId);
        }
        break;

      case 'dm':
        final conversationId = data['conversationId'] as String?;
        if (conversationId != null) {
          _navigateToChat(conversationId);
        }
        break;
    }
  }

  /// 投稿詳細画面へ遷移
  Future<void> _navigateToPost(String postId) async {
    final timelineManager = context.read<TimelineManager>();
    final post = await timelineManager.getPost(postId);
    if (post != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: post),
        ),
      );
    }
  }

  /// チャット画面へ遷移
  Future<void> _navigateToChat(String conversationId) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: conversationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationManager>().unreadCount;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 24),
            selectedIcon: Icon(Icons.home, size: 24),
            label: '',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 24),
            selectedIcon: Icon(Icons.add_circle, size: 24),
            label: '',
          ),
          NavigationDestination(
            icon: _buildNotificationIcon(unreadCount, selected: false),
            selectedIcon: _buildNotificationIcon(unreadCount, selected: true),
            label: '',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline, size: 24),
            selectedIcon: Icon(Icons.person, size: 24),
            label: '',
          ),
        ],
        onDestinationSelected: _handleDestinationSelected,
      ),
    );
  }

  static Widget _buildNotificationIcon(int unreadCount,
      {required bool selected}) {
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_none,
      size: 24,
    );
    if (unreadCount <= 0) {
      return icon;
    }
    final displayLabel = unreadCount > 99 ? '99+' : '$unreadCount';
    return Badge(
      label: Text(displayLabel),
      child: icon,
    );
  }

  void _handleDestinationSelected(int index) {
    if (index == 1) {
      _openShareComposer();
      return;
    }
    // ホームボタンが押され、かつ現在ホーム画面にいる場合はトップへスクロール
    if (index == 0 && _currentIndex == 0) {
      debugPrint(
          'HomeShell: Home button tapped on Home tab, scrolling to top.');
      _timelineKey.currentState?.scrollToTop();
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _openShareComposer() async {
    final timelineManager = context.read<TimelineManager>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom;
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: screenHeight *
                    0.8, // Show modal at ~80% of screen height per user request
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: _TimelineComposer(
                      timelineManager: timelineManager,
                      onPostSuccess: () {
                        if (Navigator.of(sheetContext).canPop()) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _autoStartStreetPass() async {
    if (_autoStartAttempted || !mounted) return;
    _autoStartAttempted = true;
    final manager = context.read<EncounterManager>();
    if (manager.isRunning) return;
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint(
          'HomeShell._autoStartStreetPass: skipping start because no FirebaseAuth user is available');
      return;
    }
    try {
      await manager.start();
    } on StreetPassException catch (error) {
      if (!mounted) return;
      _showStreetPassSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showStreetPassSnack(AppLocalizations.of(context)?.streetPassStartError ??
          'すれ違い通信の起動に失敗しました。設定を確認してください。');
    }
  }

  void _showStreetPassSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TimelineScreen extends StatefulWidget {
  const _TimelineScreen({super.key});

  @override
  State<_TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<_TimelineScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.fromTheme(theme);
    final encounterManager = context.watch<EncounterManager>();
    final timelineManager = context.watch<TimelineManager>();
    final localProfile = context.watch<ProfileController>().profile;
    final metrics = _computeMetrics(encounterManager);
    final filteredPosts = _filterTimelinePosts(
      timelineManager.posts,
      localProfile,
      encounterManager.encounters,
      encounterManager.proximityUserIds,
    );
    final feedPosts = _buildFeedPosts(filteredPosts);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          StreamBuilder<int>(
            stream: FirestoreDmService().watchTotalUnreadCount(
              context.read<ProfileController>().profile.id,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ConversationListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: AppLocalizations.of(context)?.messages ?? 'メッセージ',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => timelineManager.refresh(),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // Banner for users without username
                  if ((localProfile.username ?? '').isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileEditScreen(profile: localProfile),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_add_alt_1,
                                    color: Colors.amber.shade700, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)
                                                ?.setUsernameBannerTitle ??
                                            'ユーザーIDを設定しよう！',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppLocalizations.of(context)
                                                ?.setUsernameBannerDescription ??
                                            '@usernameでプロフィールを検索できるようになります',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Colors.amber.shade700),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  _HighlightsSection(
                    palette: palette,
                    metrics: metrics,
                    onEncounterTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const EncounterListScreen.encounters(),
                        ),
                      );
                    },
                    onReunionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EncounterListScreen.reunions(),
                        ),
                      );
                    },
                    onResonanceTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const EncounterListScreen.resonances(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  if (feedPosts.isEmpty)
                    const _EmptyTimelineMessage()
                  else
                    for (final post in feedPosts)
                      Padding(
                        key: ValueKey(post.id),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _UserPostCard(
                          post: post,
                          timelineManager: timelineManager,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<TimelinePost> _buildFeedPosts(List<TimelinePost> posts) {
  final items = List<TimelinePost>.from(posts);
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
}

List<TimelinePost> _filterTimelinePosts(
  List<TimelinePost> posts,
  Profile localProfile,
  List<Encounter> encounters,
  Set<String> proximityUserIds,
) {
  final followedIds = <String>{};
  final encounteredIds = <String>{};
  for (final encounter in encounters) {
    final id = encounter.profile.id;
    if (id.isEmpty) continue;
    encounteredIds.add(id);
    if (encounter.profile.following) {
      followedIds.add(id);
    }
  }
  final localTags = _canonicalHashtagSet(localProfile.favoriteGames);

  return posts.where((post) {
    final authorId = post.authorId;
    final isSelf =
        authorId.isEmpty || authorId == localProfile.id || authorId == 'local';
    if (isSelf) return true;
    if (followedIds.contains(authorId)) return true;
    if (encounteredIds.contains(authorId)) return true;

    // 共有ハッシュタグがあるかチェック
    final postTags = _canonicalHashtagSet(post.hashtags);
    final hasSharedHashtag = localTags.isNotEmpty &&
        postTags.isNotEmpty &&
        postTags.any(localTags.contains);

    // BLE近接範囲内のユーザーかつ共有ハッシュタグがあれば表示
    if (proximityUserIds.contains(authorId) && hasSharedHashtag) return true;

    // 共有ハッシュタグのみでも表示（既存の機能を維持）
    return hasSharedHashtag;
  }).toList();
}

Set<String> _canonicalHashtagSet(Iterable<String> rawTags) {
  final result = <String>{};
  for (final raw in rawTags) {
    final normalized = Profile.normalizeHashtag(raw);
    if (normalized == null) continue;
    final key = normalized.startsWith('#')
        ? normalized.substring(1).toLowerCase()
        : normalized.toLowerCase();
    if (key.isNotEmpty) {
      result.add(key);
    }
  }
  return result;
}

_HomeMetrics _computeMetrics(EncounterManager manager) {
  final encounters = manager.encounters;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todaysEncounters = encounters
      .where((encounter) => encounter.encounteredAt.isAfter(todayStart))
      .length;

  return _HomeMetrics(
    todaysEncounters: todaysEncounters,
    reencounters: manager.reunionCount,
    resonance: manager.resonanceCount,
  );
}

class _HomeMetrics {
  const _HomeMetrics({
    required this.todaysEncounters,
    required this.reencounters,
    required this.resonance,
  });

  final int todaysEncounters;
  final int reencounters;
  final int resonance;
}

class _HomePalette {
  _HomePalette({
    required this.background,
    required this.onSurface,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.tertiaryAccent,
  });

  final Color background;
  final Color onSurface;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color tertiaryAccent;

  factory _HomePalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _HomePalette(
      background: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.02), scheme.surface),
      onSurface: scheme.onSurface,
      primaryAccent: scheme.primary,
      secondaryAccent: scheme.secondary,
      tertiaryAccent: scheme.tertiary,
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({
    required this.palette,
    required this.metrics,
    required this.onEncounterTap,
    this.onReunionTap,
    this.onResonanceTap,
  });

  final _HomePalette palette;
  final _HomeMetrics metrics;
  final VoidCallback onEncounterTap;
  final VoidCallback? onReunionTap;
  final VoidCallback? onResonanceTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[
      _HighlightMetric(
        icon: Icons.people_alt_outlined,
        label: l10n?.encounter ?? 'すれ違い',
        value: '${metrics.todaysEncounters}',
        color: Colors.black87,
        onTap: onEncounterTap,
      ),
      _HighlightMetric(
        icon: Icons.repeat,
        label: l10n?.reunion ?? '再会',
        value: '${metrics.reencounters}',
        color: Colors.black87,
        onTap: onReunionTap,
      ),
      _HighlightMetric(
        icon: Icons.favorite,
        label: l10n?.resonance ?? '共鳴',
        value: metrics.resonance.toString(),
        color: Colors.black87,
        onTap: onResonanceTap,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFF00),
            Color(0xFFFFFF00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i != 0)
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color.withValues(alpha: 0.9),
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.75),
            fontSize: 11,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _TimelineComposer extends StatefulWidget {
  const _TimelineComposer({
    required this.timelineManager,
    this.onPostSuccess,
  });

  final TimelineManager timelineManager;
  final VoidCallback? onPostSuccess;

  @override
  State<_TimelineComposer> createState() => _TimelineComposerState();
}

class _TimelineComposerState extends State<_TimelineComposer> {
  final TextEditingController _controller = TextEditingController();
  Uint8List? _imageBytes;
  bool _submitting = false;
  final Set<String> _selectedHashtags = <String>{};
  static const int _maxHashtagSelection = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showSnack(l10n?.imageLoadError ?? '画像を読み込めませんでした。');
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final caption = _controller.text.trim();
    final hasImage = _imageBytes != null && _imageBytes!.isNotEmpty;
    if (caption.isEmpty && !hasImage) {
      _showSnack(l10n?.postValidationEmpty ?? 'テキストか画像を追加してください。');
      return;
    }
    if (_selectedHashtags.isEmpty) {
      // Use existing minHashtagsRequired if available, passing count 1
      _showSnack(l10n?.minHashtagsRequired(1) ?? 'ハッシュタグを1つ以上選んでください。');
      return;
    }
    final hashtags = Profile.sanitizeHashtags(_selectedHashtags).toList();
    setState(() => _submitting = true);
    try {
      await widget.timelineManager.addPost(
        caption: caption,
        imageBytes: _imageBytes,
        hashtags: hashtags,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _imageBytes = null;
        _selectedHashtags.clear();
      });
      FocusScope.of(context).unfocus();
      final l10n = AppLocalizations.of(context);
      _showSnack(l10n?.postSuccess ?? '投稿しました。');
      widget.onPostSuccess?.call();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _showSnack(l10n?.postFailed ?? '投稿に失敗しました。');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _removeImage() {
    setState(() => _imageBytes = null);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Compact Layout for 55% height modal
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFF2B705).withValues(alpha: 0.3),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scrollable Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 0), // Reduced Padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2B705)
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFF2B705),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Builder(builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(
                                  l10n?.shareThisMoment ?? '今の瞬間をシェア',
                                  style: AppTextStyles.shareButtonTitle,
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12), // Compact Spacing

                        Builder(builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return TextField(
                            controller: _controller,
                            minLines: 3,
                            maxLines: 5,
                            style: const TextStyle(height: 1.5),
                            decoration: InputDecoration(
                              hintText: l10n?.shareHint ?? '今の気持ちや思い出を共有...',
                              hintStyle: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.4)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          );
                        }),
                        const SizedBox(height: 12), // Compact Spacing

                        // HashtagPicker (Expands naturally)
                        HashtagPicker(
                          selectedTags: _selectedHashtags,
                          onChanged: (tags) {
                            setState(() {
                              _selectedHashtags.clear();
                              _selectedHashtags.addAll(tags);
                            });
                          },
                          maxSelection: _maxHashtagSelection,
                        ),

                        // Image Preview
                        if (_imageBytes != null) ...[
                          const SizedBox(height: 12),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 300,
                                  ),
                                  child: Image.memory(
                                    _imageBytes!,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _removeImage,
                                  icon: const Icon(Icons.close, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 100), // Bottom spacer for FABs
                      ],
                    ),
                  ),
                ),

                // Sticky Bottom Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: BorderSide(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        onPressed: _submitting ? null : _pickImage,
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 20),
                        label: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Text(l10n?.selectImage ?? '画像を選ぶ');
                          },
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF2B705)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD85F),
                              Color(0xFFF2B705),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black87),
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)?.share ?? 'シェア',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
    );
  }
}

class _UserPostCard extends StatelessWidget {
  const _UserPostCard({
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
    final hasImageUrl = (post.imageUrl?.isNotEmpty ?? false);

    // Threads風のクリーンなデザイン
    return GestureDetector(
      onTap: () => _openPostDetail(context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // アバター
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: _buildAvatar(context, theme),
                ),
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
                            child: GestureDetector(
                              onTap: () => _navigateToProfile(context),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      post.authorName.isEmpty
                                          ? (AppLocalizations.of(context)
                                                  ?.anonymous ??
                                              '匿名')
                                          : post.authorName,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (post.formattedAuthorUsername != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      post.formattedAuthorUsername!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          // 時間とメニューを配置（メニューがない場合も幅を確保して時間を揃える）
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _relativeTime(context, post.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: canDelete
                                    ? PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_horiz,
                                          size: 18,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        padding: EdgeInsets.zero,
                                        // 余白を詰める
                                        constraints: const BoxConstraints(),
                                        splashRadius: 12,
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _confirmDelete(context);
                                          }
                                        },
                                        itemBuilder: (context) {
                                          final l10n =
                                              AppLocalizations.of(context);
                                          return [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(l10n?.delete ?? '削除'),
                                            ),
                                          ];
                                        },
                                      )
                                    : null, // メニューがない場合は空のSizedBoxでスペースだけ確保（あるいはSizedBox自体を表示しない選択肢もあるが、今回は時間を揃えるためあえてスペースを確保するか、あるいはスペースなしで右端に寄せるか。ユーザーは「時間のズレ」を気にしているので、自分の投稿（メニューあり）と他人の投稿（メニューなし）で時間がずれるのを防ぐなら、この方法が良い）
                              ),
                            ],
                          ),
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
                          child: GestureDetector(
                            onTap: () => FullScreenImageViewer.show(
                              context,
                              imageBytes: imageBytes,
                              imageUrl: hasImageUrl ? post.imageUrl : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildImage(imageBytes, hasImageUrl),
                            ),
                          ),
                        ),
                      // アクションボタン（ハート + 数字）
                      _buildActions(context, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 区切り線
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, ThemeData theme) {
    // 自分の投稿の場合は現在のプロフィールアバターを使用
    final currentProfile = context.watch<ProfileController>().profile;
    final isOwnPost = post.authorId == currentProfile.id;

    if (isOwnPost) {
      // 自分の投稿なら現在のプロフィール画像を使う（ProfileAvatarのキャッシュを活用）
      return ProfileAvatar(
        profile: currentProfile,
        radius: 20,
        showBorder: false,
      );
    } else {
      // 他のユーザーの投稿なら投稿時のスナップショットを使用
      final authorProfile = Profile(
        id: post.authorId,
        beaconId: post.authorId,
        displayName: post.authorName,
        username: post.authorUsername,
        bio: '',
        homeTown: '',
        favoriteGames: const [],
        avatarColor: post.authorColor,
        avatarImageBase64: post.authorAvatarImageBase64,
      );
      return ProfileAvatar(
        profile: authorProfile,
        radius: 20,
        showBorder: false,
      );
    }
  }

  Widget _buildImage(Uint8List? imageBytes, bool hasImageUrl) {
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
      );
    }
    if (hasImageUrl) {
      return Image.network(
        post.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActions(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // いいねボタン
        GestureDetector(
          onTap: () => timelineManager.toggleLike(post.id),
          child: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color:
                post.isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // いいね数（数字のみ）
        if (post.likeCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '${post.likeCount}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(width: 16),
        // リプライ数表示
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (post.replyCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${post.replyCount}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _openPostDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(post: post),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    final encounter =
        context.read<EncounterManager>().findById('encounter_${post.authorId}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileViewScreen(
          profileId: post.authorId,
          initialProfile: encounter?.profile ??
              Profile(
                id: post.authorId,
                beaconId: post.authorId,
                displayName: post.authorName,
                avatarColor: post.authorColor,
                avatarImageBase64: post.authorAvatarImageBase64,
                bio: '読み込み中...',
                homeTown: '',
                favoriteGames: [],
              ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n?.deletePostTitle ?? '投稿を削除'),
          content: Text(l10n?.deletePostMessage ?? 'この投稿を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n?.cancel ?? 'キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n?.delete ?? '削除'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    try {
      await timelineManager.deletePost(post);
      if (context.mounted) {
        context.read<EncounterManager>().suppressVibrationFor(post.authorId);
      }
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.postDeleted ?? '投稿を削除しました。')),
      );
    } catch (error) {
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n?.deleteFailed ?? '削除に失敗しました'}: $error')),
      );
    }
  }
}

class _TimelineCardHeader extends StatelessWidget {
  const _TimelineCardHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    this.avatarImageBase64,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final String? avatarImageBase64;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedTitle = title.trim().isEmpty ? '\u533f\u540d' : title.trim();
    final initial = trimmedTitle.characters.first.toUpperCase();

    // アバター画像がある場合はデコードして表示
    MemoryImage? avatarImage;
    if (avatarImageBase64 != null && avatarImageBase64!.trim().isNotEmpty) {
      try {
        final bytes = base64Decode(avatarImageBase64!.trim());
        if (bytes.isNotEmpty) {
          avatarImage = MemoryImage(bytes);
        }
      } catch (_) {
        // デコード失敗時はデフォルト表示へ
      }
    }

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: color,
        foregroundImage: avatarImage,
        child: avatarImage == null
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        trimmedTitle,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _TimelineActions extends StatelessWidget {
  const _TimelineActions({
    required this.isLiked,
    required this.likeLabel,
    required this.onLike,
  });

  final bool isLiked;
  final String likeLabel;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onLike,
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              likeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineImage extends StatelessWidget {
  const _TimelineImage({
    this.bytes,
    this.imageUrl,
    this.borderRadius,
  });

  final Uint8List? bytes;
  final String? imageUrl;
  final BorderRadius? borderRadius;

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
          errorBuilder: (_, __, ___) => placeholder,
        );
      }
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        return Image.network(
          imageUrl!,
          fit: BoxFit.cover,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        child: buildImage(),
      ),
    );
  }
}

class _EmptyTimelineMessage extends StatelessWidget {
  const _EmptyTimelineMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '\u307e\u3060\u30bf\u30a4\u30e0\u30e9\u30a4\u30f3\u306b\u306f\u6295\u7a3f\u304c\u3042\u308a\u307e\u305b\u3093\u3002\n\u6700\u521d\u306e\u77ac\u9593\u3092\u30b7\u30a7\u30a2\u3057\u3066\u307f\u307e\u3057\u3087\u3046\uff01',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

String _relativeTime(BuildContext context, DateTime time) {
  final l10n = AppLocalizations.of(context);
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l10n?.justNow ?? 'たった今';
  if (diff.inHours < 1)
    return l10n?.minutesAgo(diff.inMinutes) ?? '${diff.inMinutes}分前';
  if (diff.inHours < 24)
    return l10n?.hoursAgo(diff.inHours) ?? '${diff.inHours}時間前';
  return l10n?.daysAgo(diff.inDays) ?? '${diff.inDays}日前';
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  StreamSubscription<ProfileInteractionSnapshot>? _statsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToOwnStats();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToOwnStats() {
    final profileController = context.read<ProfileController>();
    final service = context.read<ProfileInteractionService>();
    final myId = profileController.profile.id;
    _statsSubscription =
        service.watchProfile(targetId: myId, viewerId: myId).listen(
      (snapshot) {
        if (!mounted) return;
        profileController.updateStats(
          followersCount: snapshot.followersCount,
          followingCount: snapshot.followingCount,
          receivedLikes: snapshot.receivedLikes,
        );
      },
      onError: (error) {
        debugPrint('Failed to watch own profile stats: $error');
      },
    );
  }

  void _openRelationsSheet(
    Profile profile,
    ProfileFollowSheetMode mode,
  ) {
    final viewerId = context.read<ProfileController>().profile.id;
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ProfileFollowListSheet(
          targetId: profile.id,
          viewerId: viewerId,
          mode: mode,
          onProfileTap: (remoteProfile) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ProfileViewScreen(
                  profileId: remoteProfile.id,
                  initialProfile: remoteProfile,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openProfileEdit() async {
    if (!mounted) return;
    final controller = context.read<ProfileController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: controller.profile),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text(
                '\u30d7\u30ed\u30d5\u30a3\u30fc\u30eb\u3092\u66f4\u65b0\u3057\u307e\u3057\u305f\u3002')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = context.watch<ProfileController>().profile;
    final timelineManager = context.watch<TimelineManager>();
    final postLikesTotal = timelineManager.getPostLikesForUser(profile.id);
    final totalLikes =
        (profile.receivedLikes + postLikesTotal).clamp(0, 999999);
    final displayProfile = profile.copyWith(receivedLikes: totalLikes);
    final bio = profile.bio;
    final homeTown = profile.homeTown;
    final hashtags = profile.favoriteGames;
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)?.settings ?? '設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // プロフィールとタイムラインを更新
                    // Note: ProfileController doesn't have a public refresh, assuming updateProfile triggers reload if needed.
                    // For now, refreshing timeline is the most visible action.
                    await context.read<TimelineManager>().refresh();
                    // updateProfile call removed as it requires a non-null Profile object and lacks a reload mechanism.
                    // Relying on TimelineManager refresh for now.
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Material(
                              color: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: InkWell(
                                onTap: _openProfileEdit,
                                borderRadius: BorderRadius.circular(28),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: ProfileAvatar(
                                    profile: profile,
                                    radius: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if ((profile.username ?? '').isNotEmpty)
                                  Text(
                                    '@${profile.username}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _openProfileEdit,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color:
                                    theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context);
                                return Text(l10n?.editProfile ?? 'プロフィールを編集');
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ProfileStatsRow(
                          profile: displayProfile,
                          onFollowersTap: () => _openRelationsSheet(
                            profile,
                            ProfileFollowSheetMode.followers,
                          ),
                          onFollowingTap: () => _openRelationsSheet(
                            profile,
                            ProfileFollowSheetMode.following,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          l10n?.status ?? 'ステータス',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ProfileInfoTile(
                          icon: Icons.mood,
                          title: l10n?.bio ?? '一言コメント',
                          value: _displayOrPlaceholder(context, bio),
                        ),
                        ProfileInfoTile(
                          icon: Icons.place_outlined,
                          title: l10n?.activeArea ?? '活動エリア',
                          value: _displayOrPlaceholder(context, homeTown),
                        ),
                        ProfileInfoTile(
                          icon: Icons.tag,
                          title: l10n?.hashtags ?? 'ハッシュタグ',
                          value: _hashtagsOrPlaceholder(context, hashtags),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          AppLocalizations.of(context)?.timeline ?? 'タイムライン',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _ProfileTimelineTabs(
                          profileId: profile.id,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayOrPlaceholder(BuildContext context, String value) {
  final trimmed = value.trim();
  final l10n = AppLocalizations.of(context);
  final defaults = const {'未登録', '未設定', 'Not set', 'Unregistered'};
  if (trimmed.isEmpty || defaults.contains(trimmed)) {
    return l10n?.unregistered ?? '未登録';
  }
  return trimmed;
}

String _hashtagsOrPlaceholder(BuildContext context, List<String> hashtags) {
  final l10n = AppLocalizations.of(context);
  if (hashtags.isEmpty) {
    return l10n?.unregistered ?? '未登録';
  }
  return hashtags.join(' ');
}

class _ProfileTimelineTabs extends StatefulWidget {
  const _ProfileTimelineTabs({required this.profileId});

  final String profileId;

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
    final timelineManager = context.watch<TimelineManager>();
    final posts = timelineManager.posts
        .where((post) => post.authorId == widget.profileId)
        .toList();
    final mediaPosts = posts
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
          tabs: [
            Tab(text: AppLocalizations.of(context)?.posts ?? '投稿'),
            Tab(text: AppLocalizations.of(context)?.media ?? 'メディア'),
          ],
        ),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              // 投稿タブ
              _PostsTabContent(
                posts: posts,
                timelineManager: timelineManager,
              ),
              // メディアタブ
              _MediaTabContent(posts: mediaPosts),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostsTabContent extends StatelessWidget {
  const _PostsTabContent({
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
          AppLocalizations.of(context)?.noPostsYet ?? 'まだ投稿がありません',
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
        return _UserPostCard(
          post: post,
          timelineManager: timelineManager,
        );
      },
    );
  }
}

class _MediaTabContent extends StatelessWidget {
  const _MediaTabContent({required this.posts});

  final List<TimelinePost> posts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (posts.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.noMedia ?? 'メディアがありません',
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
      },
    );
  }
}
