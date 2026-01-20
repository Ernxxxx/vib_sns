import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/encounter.dart';
import '../services/streetpass_service.dart';
import '../state/encounter_manager.dart';
import '../state/runtime_config.dart';
import '../utils/color_extensions.dart';
import '../widgets/app_logo.dart';
import '../widgets/emotion_map.dart';
import '../widgets/like_button.dart';
import '../widgets/profile_avatar.dart';
import 'profile_view_screen.dart';

enum EncounterListFilter { encounter, reunion, resonance }

class EncounterListScreen extends StatefulWidget {
  const EncounterListScreen(
      {super.key, this.initialFilter = EncounterListFilter.encounter});
  const EncounterListScreen.encounters({super.key})
      : initialFilter = EncounterListFilter.encounter;
  const EncounterListScreen.reunions({super.key})
      : initialFilter = EncounterListFilter.reunion;
  const EncounterListScreen.resonances({super.key})
      : initialFilter = EncounterListFilter.resonance;

  final EncounterListFilter initialFilter;

  @override
  State<EncounterListScreen> createState() => _EncounterListScreenState();
}

class _EncounterListScreenState extends State<EncounterListScreen> {
  bool _scanAttempted = false;
  late EncounterListFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureStreetPassStarted();
    });
  }

  Future<void> _handleRefresh() async {
    await context.read<EncounterManager>().refresh();
  }

  Future<void> _ensureStreetPassStarted() async {
    final manager = context.read<EncounterManager>();
    if (manager.isRunning) return;
    try {
      await manager.start();
      if (mounted) {
        setState(() {
          _scanAttempted = true;
        });
      }
    } on StreetPassException catch (error) {
      if (mounted) {
        setState(() => _scanAttempted = true);
      }
      _showSnack(error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _scanAttempted = true);
      }
      final l10n = AppLocalizations.of(context);
      _showSnack(
          l10n?.encounterStartFailed ?? 'すれ違い通信を開始できませんでした。設定を確認してください。');
    }
  }

  Future<void> _handleScanPressed() async {
    final manager = context.read<EncounterManager>();
    setState(() => _scanAttempted = true);
    try {
      await manager.reset();
      await manager.start();
      final l10n = AppLocalizations.of(context);
      _showSnack(l10n?.scanningNearby ?? '近くのプレイヤーをスキャンしています...');
    } on StreetPassException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      final l10n = AppLocalizations.of(context);
      _showSnack(l10n?.initFailed ?? '通信の初期化に失敗しました。');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final runtimeConfig = context.watch<StreetPassRuntimeConfig>();
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppLogo(),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: l10n?.rescan ?? '再読み込み',
              icon: const Icon(Icons.refresh),
              onPressed: _handleScanPressed,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.list_alt),
                text: l10n?.listTab ?? 'リスト',
              ),
              Tab(
                icon: const Icon(Icons.map_outlined),
                text: l10n?.mapTab ?? 'マップ',
              ),
            ],
          ),
        ),
        body: Consumer<EncounterManager>(
          builder: (context, manager, _) {
            if (manager.errorMessage != null) {
              return _ErrorMessage(message: manager.errorMessage!);
            }
            if (!manager.isRunning) {
              return _LoadingMessage(
                attempted: _scanAttempted,
                onRetry: _handleScanPressed,
              );
            }

            final encounters = manager.encounters;
            final reunionEntries = manager.reunionEntries;
            final resonanceEntries = manager.resonanceEntries;

            List<Widget> buildBanners() {
              return [
                if (runtimeConfig.usesMockService)
                  _BannerMessage(
                    icon: Icons.info_outline,
                    text: l10n?.demoModeMessage ??
                        '現在はデモモードで動作しています。Firebase連携後に実際のすれ違いが可能になります。',
                  ),
                if (runtimeConfig.usesMockBle)
                  _BannerMessage(
                    icon: Icons.bluetooth_disabled_outlined,
                    text: l10n?.demoBleMessage ??
                        'BLE近接検知は現在デモデータで動作中です。実機ではBluetoothを有効にしてください。',
                  ),
              ];
            }

            Widget buildFilteredList() {
              final filter = _selectedFilter;
              if (filter == EncounterListFilter.encounter) {
                if (encounters.isEmpty) {
                  return Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        children: [
                          _EmptyEncountersMessage(
                            scanAttempted: _scanAttempted,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      itemBuilder: (context, index) {
                        final encounter = encounters[index];
                        return _EncounterTile(encounter: encounter);
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: encounters.length,
                    ),
                  ),
                );
              }
              final entries = filter == EncounterListFilter.reunion
                  ? reunionEntries
                  : resonanceEntries;
              if (entries.isEmpty) {
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(l10n?.noRecordsYet ?? 'まだ記録がありません。'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _HighlightEntryTile(entry: entry);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: entries.length,
                  ),
                ),
              );
            }

            final filterRow = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<EncounterListFilter>(
                segments: [
                  ButtonSegment(
                    value: EncounterListFilter.encounter,
                    label: Text(l10n?.encounter ?? 'すれ違い'),
                    icon: const Icon(Icons.people_alt_outlined),
                  ),
                  ButtonSegment(
                    value: EncounterListFilter.reunion,
                    label: Text(l10n?.reunion ?? '再会'),
                    icon: const Icon(Icons.repeat),
                  ),
                  ButtonSegment(
                    value: EncounterListFilter.resonance,
                    label: Text(l10n?.resonance ?? '共鳴'),
                    icon: const Icon(Icons.favorite_border),
                  ),
                ],
                selected: {_selectedFilter},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  setState(() => _selectedFilter = selection.first);
                },
              ),
            );

            final listTab = Column(
              children: [
                ...buildBanners(),
                filterRow,
                buildFilteredList(),
              ],
            );

            final mapTab = Column(
              children: [
                ...buildBanners(),
                const Expanded(
                  child: EmotionMap(),
                ),
              ],
            );

            return TabBarView(
              children: [
                listTab,
                mapTab,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EncounterTile extends StatelessWidget {
  const _EncounterTile({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final distance = encounter.displayDistance;
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          context.read<EncounterManager>().markSeen(encounter.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileViewScreen(
                profileId: encounter.profile.id,
                initialProfile: encounter.profile,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: encounter.unread
                  ? accent.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: encounter.unread
                    ? accent.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(profile: encounter.profile),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                encounter.profile.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (encounter.profile.formattedUsername != null)
                                Text(
                                  encounter.profile.formattedUsername!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatRelativeTime(encounter.encounteredAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (encounter.message != null &&
                        encounter.message!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          encounter.message!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (distance != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          encounter.proximityVerified
                              ? (l10n?.bleProximity(
                                      distance.toStringAsFixed(2)) ??
                                  'BLE近接 約${distance.toStringAsFixed(2)}m')
                              : (l10n?.gpsEstimated(
                                      distance.round().toString()) ??
                                  'GPS推定 約${distance.round()}m'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double availableWidth = constraints.maxWidth;
                        final double rawWidth = (availableWidth - 10) / 2;
                        final double buttonWidth =
                            rawWidth.isFinite && rawWidth > 0
                                ? rawWidth
                                : availableWidth / 2;
                        return Row(
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: LikeButton(
                                  variant: LikeButtonVariant.chip,
                                  isLiked: encounter.liked,
                                  likeCount: 0,
                                  onPressed: () {
                                    context
                                        .read<EncounterManager>()
                                        .toggleLike(encounter.id);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: buttonWidth,
                              child: FittedBox(
                                alignment: Alignment.centerRight,
                                fit: BoxFit.scaleDown,
                                child: FollowButton(
                                  variant: LikeButtonVariant.chip,
                                  isFollowing: encounter.profile.following,
                                  onPressed: () {
                                    context
                                        .read<EncounterManager>()
                                        .toggleFollow(encounter.id);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightEntryTile extends StatelessWidget {
  const _HighlightEntryTile({required this.entry});

  final EncounterHighlightEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = context.watch<EncounterManager>();

    // Find the corresponding encounter
    Encounter? matchedEncounter;
    for (final encounter in manager.encounters) {
      if (encounter.profile.id == entry.profile.id) {
        matchedEncounter = encounter;
        break;
      }
    }

    final accent = theme.colorScheme.primary;
    final distance = matchedEncounter?.displayDistance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (matchedEncounter != null) {
            manager.markSeen(matchedEncounter.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileViewScreen(
                  profileId: matchedEncounter!.profile.id,
                  initialProfile: matchedEncounter.profile,
                ),
              ),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (matchedEncounter?.unread ?? false)
                  ? accent.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (matchedEncounter?.unread ?? false)
                    ? accent.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(profile: entry.profile),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.profile.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (entry.profile.formattedUsername != null)
                                Text(
                                  entry.profile.formattedUsername!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4C7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatRelativeTime(entry.occurredAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (matchedEncounter?.message != null &&
                        matchedEncounter!.message!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          matchedEncounter.message!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    if (distance != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          matchedEncounter!.proximityVerified
                              ? (AppLocalizations.of(context)?.bleProximity(
                                      distance.toStringAsFixed(2)) ??
                                  'BLE近接 約${distance.toStringAsFixed(2)}m')
                              : (AppLocalizations.of(context)?.gpsEstimated(
                                      distance.round().toString()) ??
                                  'GPS推定 約${distance.round()}m'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double availableWidth = constraints.maxWidth;
                        final double rawWidth = (availableWidth - 10) / 2;
                        final double buttonWidth =
                            rawWidth.isFinite && rawWidth > 0
                                ? rawWidth
                                : availableWidth / 2;
                        if (matchedEncounter == null) {
                          return const SizedBox.shrink();
                        }
                        return Row(
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: LikeButton(
                                  variant: LikeButtonVariant.chip,
                                  isLiked: matchedEncounter.liked,
                                  likeCount: 0,
                                  onPressed: () {
                                    context
                                        .read<EncounterManager>()
                                        .toggleLike(matchedEncounter!.id);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: buttonWidth,
                              child: FittedBox(
                                alignment: Alignment.centerRight,
                                fit: BoxFit.scaleDown,
                                child: FollowButton(
                                  variant: LikeButtonVariant.chip,
                                  isFollowing:
                                      matchedEncounter.profile.following,
                                  onPressed: () {
                                    context
                                        .read<EncounterManager>()
                                        .toggleFollow(matchedEncounter!.id);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '\u305f\u3063\u305f\u4eca';
  if (diff.inHours < 1) return '${diff.inMinutes}\u5206\u524d';
  if (diff.inHours < 24) return '${diff.inHours}\u6642\u9593\u524d';
  return '${diff.inDays}\u65e5\u524d';
}

class _EmptyEncountersMessage extends StatelessWidget {
  const _EmptyEncountersMessage({required this.scanAttempted});

  final bool scanAttempted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sensors, size: 64, color: Color(0xFFFFC400)),
          const SizedBox(height: 16),
          Text(
            scanAttempted
                ? (l10n?.noEncountersAfterScan ??
                    '今回はすれ違いがありませんでした。\n外出して再度スキャンしてみましょう。')
                : (l10n?.noEncountersInitial ??
                    'まだすれ違いがありません。近くのプレイヤーを探してみましょう。'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMessage extends StatelessWidget {
  const _LoadingMessage({required this.attempted, required this.onRetry});

  final bool attempted;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            attempted
                ? (l10n?.initializingRetry ?? '現在初期化中です...変化がない場合は再試行してください。')
                : (l10n?.initializingPlsWait ?? '初回起動中です。しばらくお待ちください。'),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n?.rescanButton ?? '再スキャン'),
          ),
        ],
      ),
    );
  }
}

class _BannerMessage extends StatelessWidget {
  const _BannerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
