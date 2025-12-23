import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_streetpass_service.dart';

import 'encounter_list_screen.dart';
import 'notifications_screen.dart';
import '../data/preset_hashtags.dart';
import '../services/streetpass_service.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/emotion_map_manager.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import 'profile_edit_screen.dart';
import '../models/profile.dart';
import '../models/encounter.dart';
import '../utils/color_extensions.dart';
import 'package:vib_sns/models/timeline_post.dart';
import '../widgets/app_logo.dart';
import '../widgets/profile_avatar.dart';
import '../utils/app_text_styles.dart';
import '../widgets/profile_info_tile.dart';
import '../widgets/profile_stats_row.dart';
import 'profile_follow_list_sheet.dart';
import 'profile_view_screen.dart';
import '../utils/auth_helpers.dart';

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
    });
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
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _TimelineComposer(
                    timelineManager: timelineManager,
                    onPostSuccess: () => Navigator.of(sheetContext).pop(),
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
      _showStreetPassSnack(
          '\u3059\u308c\u9055\u3044\u901a\u4fe1\u306e\u8d77\u52d5\u306b\u5931\u6557\u3057\u307e\u3057\u305f\u3002\u8a2d\u5b9a\u3092\u78ba\u8a8d\u3057\u3066\u304f\u3060\u3055\u3044\u3002');
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
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: true,
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
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
    final tiles = <Widget>[
      _HighlightMetric(
        icon: Icons.people_alt_outlined,
        label: '\u3059\u308c\u9055\u3044',
        value: '${metrics.todaysEncounters}',
        color: Colors.black87,
        onTap: onEncounterTap,
      ),
      _HighlightMetric(
        icon: Icons.repeat,
        label: '\u518d\u4f1a',
        value: '${metrics.reencounters}',
        color: Colors.black87,
        onTap: onReunionTap,
      ),
      _HighlightMetric(
        icon: Icons.favorite,
        label: '\u5171\u9cf4',
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
      _showSnack(
          '\u753b\u50cf\u3092\u8aad\u307f\u8fbc\u3081\u307e\u305b\u3093\u3067\u3057\u305f\u3002');
    }
  }

  Future<void> _submit() async {
    final caption = _controller.text.trim();
    final hasImage = _imageBytes != null && _imageBytes!.isNotEmpty;
    if (caption.isEmpty && !hasImage) {
      _showSnack(
          '\u30c6\u30ad\u30b9\u30c8\u304b\u753b\u50cf\u3092\u8ffd\u52a0\u3057\u3066\u304f\u3060\u3055\u3044\u3002');
      return;
    }
    if (_selectedHashtags.isEmpty) {
      _showSnack(
          '\u30cf\u30c3\u30b7\u30e5\u30bf\u30b0\u30921\u3064\u4ee5\u4e0a\u9078\u3093\u3067\u304f\u3060\u3055\u3044\u3002');
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
      _showSnack('投稿しました。');
      widget.onPostSuccess?.call();
    } catch (_) {
      if (!mounted) return;
      _showSnack('投稿に失敗しました。');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _removeImage() {
    setState(() => _imageBytes = null);
  }

  void _toggleHashtag(String tag) {
    setState(() {
      if (_selectedHashtags.contains(tag)) {
        _selectedHashtags.remove(tag);
      } else {
        if (_selectedHashtags.length >= _maxHashtagSelection) {
          _showSnack(
              '\u30cf\u30c3\u30b7\u30e5\u30bf\u30b0\u306f$_maxHashtagSelection\u500b\u307e\u3067\u9078\u3079\u307e\u3059\u3002');
          return;
        }
        _selectedHashtags.add(tag);
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            color:
                                const Color(0xFFF2B705).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFF2B705),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '今の瞬間をシェア',
                          style: AppTextStyles.shareButtonTitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(height: 1.5),
                    decoration: InputDecoration(
                      hintText: '今の気持ちや思い出を共有...',
                      hintStyle:
                          TextStyle(color: Colors.black.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ハッシュタグを選ぶ (最大$_maxHashtagSelection個)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in presetHashtags)
                            FilterChip(
                              showCheckmark: false,
                              label: Text(tag),
                              selected: _selectedHashtags.contains(tag),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.6),
                              selectedColor: const Color(0xFFF2B705)
                                  .withValues(alpha: 0.2),
                              side: BorderSide(
                                color: _selectedHashtags.contains(tag)
                                    ? const Color(0xFFF2B705)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                              labelStyle: TextStyle(
                                color: _selectedHashtags.contains(tag)
                                    ? Colors.black87
                                    : Colors.black54,
                                fontWeight: _selectedHashtags.contains(tag)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) => _toggleHashtag(tag),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_imageBytes != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            _imageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.5),
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
                        label: const Text('画像を選ぶ'),
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
                              : const Text(
                                  'シェア',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
    final likeLabel = post.likeCount > 0
        ? '${post.likeCount}\u4ef6\u306e\u3044\u3044\u306d'
        : '\u307e\u3060\u3044\u3044\u306d\u306f\u3042\u308a\u307e\u305b\u3093';

    // マットで洗練されたグラスモーフィズム
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // 影は控えめに、色なしで
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              // 背景は少し白/グレーを混ぜてマット感を出す
              color: theme.colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _TimelineCardHeader(
                    title: post.authorName,
                    subtitle: _relativeTime(post.createdAt),
                    color: post.authorColor,
                    avatarImageBase64: post.authorAvatarImageBase64,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileViewScreen(
                            profileId: post.authorId,
                            initialProfile: Profile(
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
                    },
                    trailing: canDelete
                        ? PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz,
                                color: theme.colorScheme.onSurfaceVariant),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _confirmDelete(context);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('\u524a\u9664'),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                if (imageBytes != null || hasImageUrl)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child: _TimelineImage(
                      bytes: imageBytes,
                      imageUrl: hasImageUrl ? post.imageUrl : null,
                      borderRadius: BorderRadius.circular(0), // 画像はエッジトゥエッジ気味に
                    ),
                  ),
                if (post.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Text(
                      post.caption,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
                      ),
                    ),
                  ),
                if (post.hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in post.hashtags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    theme.colorScheme.outline.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _TimelineActions(
                    isLiked: post.isLiked,
                    likeLabel: likeLabel,
                    onLike: () {
                      timelineManager.toggleLike(post.id);
                    },
                  ),
                ),
              ],
            ),
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
        return AlertDialog(
          title: const Text('\u6295\u7a3f\u3092\u524a\u9664'),
          content: const Text(
              '\u3053\u306e\u6295\u7a3f\u3092\u524a\u9664\u3057\u307e\u3059\u304b\uff1f'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\u30ad\u30e3\u30f3\u30bb\u30eb'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('\u524a\u9664'),
            ),
          ],
        );
      },
    );
    if (result != true) return;
    try {
      await timelineManager.deletePost(post);
      // 投稿を削除した相手からの振動を抑制する
      if (context.mounted) {
        context.read<EncounterManager>().suppressVibrationFor(post.authorId);
      }
      messenger.showSnackBar(
        const SnackBar(
            content: Text(
                '\u6295\u7a3f\u3092\u524a\u9664\u3057\u307e\u3057\u305f\u3002')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '\u524a\u9664\u306b\u5931\u6557\u3057\u307e\u3057\u305f: $error')),
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

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '\u305f\u3063\u305f\u4eca';
  if (diff.inHours < 1) return '${diff.inMinutes}\u5206\u524d';
  if (diff.inHours < 24) return '${diff.inHours}\u6642\u9593\u524d';
  return '${diff.inDays}\u65e5\u524d';
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    final controller = context.read<ProfileController>();
    final manager = context.read<EncounterManager>();
    final notificationManager = context.read<NotificationManager>();
    final timelineManager = context.read<TimelineManager>();
    final emotionMapManager = context.read<EmotionMapManager>();
    try {
      // 認証がクリアされる前にサブスクリプションを停止（権限エラー回避）
      manager.pauseProfileSync();
      notificationManager.pauseForLogout();
      timelineManager.pauseForLogout();
      emotionMapManager.pauseForLogout();

      // 認証が有効な間にstreetpass_presencesをクリーンアップ
      try {
        await _deleteStreetpassPresence(
          profileId: controller.profile.id,
          beaconId: controller.profile.beaconId,
        );
      } catch (e, st) {
        debugPrint('Failed to delete streetpass presence: $e');
        debugPrintStack(stackTrace: st);
      }

      // ユーザーが認証済みの場合、ローカル状態をクリアする前に
      // サーバー側関数を呼び出してプロフィールと関連データを削除
      final user = FirebaseAuth.instance.currentUser;
      var serverDeleted = false;
      if (user != null) {
        try {
          debugPrint(
              'HomeShell._logout: calling deleteUserProfile for profileId=${controller.profile.id} beaconId=${controller.profile.beaconId}');
          final callable =
              FirebaseFunctions.instance.httpsCallable('deleteUserProfile');
          final result = await callable.call(<String, dynamic>{
            'profileId': controller.profile.id,
            'beaconId': controller.profile.beaconId,
          });
          debugPrint(
              'HomeShell._logout: deleteUserProfile result=${result.data}');
          serverDeleted = true;
        } catch (e, st) {
          debugPrint('deleteUserProfile failed: $e');
          debugPrintStack(stackTrace: st);
          // フォールバック: 認証が有効な間にクライアント側でクリーンアップ
          await _purgeProfileData(
            profileId: controller.profile.id,
            beaconId: controller.profile.beaconId,
          );
        }
      }

      // Firebase Authからサインアウト
      debugPrint('HomeShell._logout: signing out FirebaseAuth');
      await FirebaseAuth.instance.signOut();

      // ローカルに保存されたタイムライン投稿をクリア
      await timelineManager.clearPostsForCurrentProfile();

      if (serverDeleted) {
        // サーバー側削除が成功した場合のみローカルIDをリセット
        // これによりサーバーが削除できなかった場合のプロフィール增殖を防止
        debugPrint(
            'HomeShell._logout: resetting local profile with wipeIdentity=true');
        await LocalProfileLoader.resetLocalProfile(wipeIdentity: true);
        final refreshed = await LocalProfileLoader.loadOrCreate();
        debugPrint(
            'HomeShell._logout: new local profile id=${refreshed.id} beaconId=${refreshed.beaconId}');
        // ログアウト時はプロフィールをブートストラップせずサーバー統計再購読もしない
        await manager.switchLocalProfile(refreshed, skipSync: true);
        // ここでresetForProfileを呼ばない - まだ認証されていないため
        // マネージャーはNameSetupScreenでログイン後に再起動される
        // ログアウト時にUI表示の統計をゼロにリセット
        controller.updateStats(
            followersCount: 0, followingCount: 0, receivedLikes: 0);
        controller.updateProfile(refreshed, needsSetup: true);
      } else {
        // サーバー削除が失敗または未実行。ローカルIDは保持して
        // 次回起動時に新しいプロフィールが作られるのを防止
        debugPrint(
            'HomeShell._logout: server deletion failed or not attempted; wiping local identity to avoid lingering presence');
        await LocalProfileLoader.resetLocalProfile(wipeIdentity: true);
        final refreshed = await LocalProfileLoader.loadOrCreate();
        await manager.switchLocalProfile(refreshed, skipSync: true);
        // ここでresetForProfileを呼ばない - まだ認証されていないため
        controller.updateStats(
            followersCount: 0, followingCount: 0, receivedLikes: 0);
        controller.updateProfile(refreshed, needsSetup: true);
      }

      // 即座に匿名認証を再確立してFirestoreアクセスを維持
      await ensureAnonymousAuth();
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _deleteStreetpassPresence({
    required String profileId,
    required String beaconId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final presences = firestore.collection('streetpass_presences');

    // Get the actual deviceId from SharedPreferences (this is the document ID)
    String? deviceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString(FirestoreStreetPassService.prefsDeviceIdKey);
      debugPrint('Found deviceId from SharedPreferences: $deviceId');
    } catch (e) {
      debugPrint('Failed to get deviceId from SharedPreferences: $e');
    }

    // Delete by deviceId (the actual document ID used by FirestoreStreetPassService)
    if (deviceId != null && deviceId.isNotEmpty) {
      try {
        debugPrint('Deleting streetpass_presences doc by deviceId: $deviceId');
        await presences.doc(deviceId).delete();
      } catch (e) {
        debugPrint('Failed to delete presence doc by deviceId: $e');
      }
    }

    // Also try deleting by profileId (fallback if they differ)
    if (profileId != deviceId) {
      try {
        debugPrint(
            'Deleting streetpass_presences doc by profileId: $profileId');
        await presences.doc(profileId).delete();
      } catch (e) {
        debugPrint('Failed to delete presence doc by profileId: $e');
      }
    }

    // Delete any doc with matching profile.id
    try {
      final byProfileId =
          await presences.where('profile.id', isEqualTo: profileId).get();
      debugPrint(
          'Found ${byProfileId.docs.length} docs with profile.id=$profileId');
      for (final doc in byProfileId.docs) {
        debugPrint('Deleting presence doc ${doc.id} (matched by profile.id)');
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Failed to query/delete by profile.id: $e');
    }

    // Also query by deviceId in profile.id
    if (deviceId != null && deviceId != profileId) {
      try {
        final byDeviceId =
            await presences.where('profile.id', isEqualTo: deviceId).get();
        debugPrint(
            'Found ${byDeviceId.docs.length} docs with profile.id=$deviceId');
        for (final doc in byDeviceId.docs) {
          debugPrint(
              'Deleting presence doc ${doc.id} (matched by deviceId in profile.id)');
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Failed to query/delete by deviceId in profile.id: $e');
      }
    }

    // Delete any doc with the same beaconId
    try {
      final byBeacon =
          await presences.where('profile.beaconId', isEqualTo: beaconId).get();
      debugPrint(
          'Found ${byBeacon.docs.length} docs with profile.beaconId=$beaconId');
      for (final doc in byBeacon.docs) {
        debugPrint('Deleting presence doc ${doc.id} (matched by beaconId)');
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Failed to query/delete by beaconId: $e');
    }
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
    try {
      final emotions = await firestore
          .collection('emotion_map_posts')
          .where('profileId', isEqualTo: profileId)
          .get();
      for (final doc in emotions.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
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
    final profile = context.watch<ProfileController>().profile;
    final bio = _displayOrPlaceholder(profile.bio);
    final homeTown = _displayOrPlaceholder(profile.homeTown);
    final hashtags = _hashtagsOrPlaceholder(profile.favoriteGames);
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '\u7de8\u96c6',
            onPressed: _openProfileEdit,
            icon: const Icon(Icons.edit_outlined),
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
                                Text(
                                  '\u30b5\u30de\u30ea\u30fc\u3092\u7de8\u96c6\u3057\u3066\n\u3042\u306a\u305f\u3089\u3057\u3055\u3092\u5c4a\u3051\u307e\u3057\u3087\u3046\u3002',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        ProfileStatsRow(
                          profile: profile,
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
                          '\u30b9\u30c6\u30fc\u30bf\u30b9',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ProfileInfoTile(
                          icon: Icons.mood,
                          title: '\u4e00\u8a00\u30b3\u30e1\u30f3\u30c8',
                          value: bio,
                        ),
                        ProfileInfoTile(
                          icon: Icons.place_outlined,
                          title: '\u6d3b\u52d5\u30a8\u30ea\u30a2',
                          value: homeTown,
                        ),
                        ProfileInfoTile(
                          icon: Icons.tag,
                          title: '\u30cf\u30c3\u30b7\u30e5\u30bf\u30b0',
                          value: hashtags,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'タイムライン',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _ProfileTimelineSection(
                          profileId: profile.id,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                ),
                onPressed: _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout),
                label: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('\u30ed\u30b0\u30a2\u30a6\u30c8'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayOrPlaceholder(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '\u672a\u767b\u9332') {
    return '\u672a\u767b\u9332';
  }
  return trimmed;
}

String _hashtagsOrPlaceholder(List<String> hashtags) {
  if (hashtags.isEmpty) {
    return '\u672a\u767b\u9332';
  }
  return hashtags.join(' ');
}

class _ProfileTimelineSection extends StatelessWidget {
  const _ProfileTimelineSection({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineManager = context.watch<TimelineManager>();
    final posts = timelineManager.posts
        .where((post) => post.authorId == profileId)
        .toList();

    if (posts.isEmpty) {
      return Text(
        'まだ投稿がありません。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    // 最新5件
    final visiblePosts = posts.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in visiblePosts)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _UserPostCard(
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
