import 'package:flutter/material.dart';

import '../data/preset_hashtags.dart';

/// モダンなハッシュタグ選択ウィジェット
///
/// カテゴリ別表示、検索機能、選択済みタグの上部表示を提供
class HashtagPicker extends StatefulWidget {
  const HashtagPicker({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    this.minSelection = 2,
    this.maxSelection = 10,
    this.availableTags,
  });

  /// 現在選択されているタグのセット
  final Set<String> selectedTags;

  /// 選択が変更されたときのコールバック
  final ValueChanged<Set<String>> onChanged;

  /// 最小選択数
  final int minSelection;

  /// 最大選択数
  final int maxSelection;

  /// 利用可能なタグ（nullの場合はpresetHashtagsを使用）
  final List<String>? availableTags;

  @override
  State<HashtagPicker> createState() => _HashtagPickerState();
}

class _HashtagPickerState extends State<HashtagPicker> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // 最初のカテゴリを展開状態にする
    if (categoryOrder.isNotEmpty) {
      _expandedCategories.add(categoryOrder.first);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    final newSelection = Set<String>.from(widget.selectedTags);
    if (newSelection.contains(tag)) {
      newSelection.remove(tag);
    } else {
      if (newSelection.length >= widget.maxSelection) {
        _showMaxSelectionSnack();
        return;
      }
      newSelection.add(tag);
    }
    widget.onChanged(newSelection);
  }

  void _showMaxSelectionSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ハッシュタグは${widget.maxSelection}件まで選べます'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<String> _filterTags(List<String> tags) {
    if (_searchQuery.isEmpty) return tags;
    final query = _searchQuery.toLowerCase();
    return tags.where((tag) => tag.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー：選択数表示
        _buildHeader(theme, colorScheme),
        const SizedBox(height: 16),

        // 選択済みタグ表示
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: widget.selectedTags.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildSelectedTags(colorScheme),
                )
              : const SizedBox.shrink(),
        ),

        // 検索バー
        _buildSearchBar(theme, colorScheme),
        const SizedBox(height: 20),

        // カテゴリ別タグリスト
        _buildCategoryList(theme, colorScheme),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final count = widget.selectedTags.length;
    final isValid = count >= widget.minSelection;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.tag,
            size: 18,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ハッシュタグを選択',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isValid
                ? colorScheme.primaryContainer
                : colorScheme.errorContainer.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isValid ? colorScheme.primary : colorScheme.error)
                    .withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isValid
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                ' / ${widget.maxSelection}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isValid
                      ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                      : colorScheme.onErrorContainer.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTags(ColorScheme colorScheme) {
    if (widget.selectedTags.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons
                      .label_important_outline, // auto_awesome was too decorative
                  size: 18,
                  color: colorScheme.primary, // Solid color, no shader mask
                ),
                const SizedBox(width: 8),
                Text(
                  'SELECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700, // Slightly less heavy
                    color: colorScheme.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.selectedTags.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: widget.selectedTags.map((tag) {
              return _SelectedTagChip(
                tag: tag,
                onRemove: () => _toggleTag(tag),
                colorScheme: colorScheme,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'SEARCH KEYWORD...',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.3),
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.primary.withOpacity(0.8),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildCategoryList(ThemeData theme, ColorScheme colorScheme) {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults(theme, colorScheme);
    }

    return Column(
      children: categoryOrder.map((categoryName) {
        final category = hashtagCategories[categoryName];
        if (category == null) return const SizedBox.shrink();

        final isExpanded = _expandedCategories.contains(categoryName);
        final selectedInCategory = category.tags
            .where((tag) => widget.selectedTags.contains(tag))
            .length;

        // Revert to sharp/tech container style
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            // Removed background color for expanded state to reduce glare
            color: Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isExpanded ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Theme(
            data: theme.copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedCategories.add(categoryName);
                  } else {
                    _expandedCategories.remove(categoryName);
                  }
                });
              },
              tilePadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              leading: Text(
                category.icon,
                style: const TextStyle(fontSize: 20), // Standard size
              ),
              title: Row(
                children: [
                  Text(
                    categoryName.toUpperCase(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedInCategory > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$selectedInCategory',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
              trailing: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                Wrap(
                  spacing: 12, // 間隔を広げて浮遊感
                  runSpacing: 12,
                  children: category.tags.map((tag) {
                    final isSelected = widget.selectedTags.contains(tag);
                    return _HashtagChip(
                      tag: tag,
                      isSelected: isSelected,
                      onTap: () => _toggleTag(tag),
                      colorScheme: colorScheme,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults(ThemeData theme, ColorScheme colorScheme) {
    // ... (検索結果部分はcategoryListと同様のスタイル変更が適用されるため、基本的な構造は維持しつつChipが変わる)
    final allTags = widget.availableTags ?? presetHashtags;
    final filteredTags = _filterTags(allTags);

    if (filteredTags.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.manage_search,
              size: 48,
              color: colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20, top: 10),
          child: Row(
            children: [
              Text(
                'RESULTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${filteredTags.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filteredTags.map((tag) {
            final isSelected = widget.selectedTags.contains(tag);
            return _HashtagChip(
              tag: tag,
              isSelected: isSelected,
              onTap: () => _toggleTag(tag),
              colorScheme: colorScheme,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final String tag;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30), // Chips remain Round/Capsule
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // Removed gradient and reduced glare
            color: isSelected
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius:
                BorderRadius.circular(30), // Chips remain Round/Capsule
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary // Single solid color, no opacity games
                  : Colors.transparent,
              width: 1.5,
            ),
            // Removed glow/shadow completely for a flatter, cleaner look
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected
                  ? FontWeight.w700
                  : FontWeight.w500, // Slightly less bold
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedTagChip extends StatelessWidget {
  const _SelectedTagChip({
    required this.tag,
    required this.onRemove,
    required this.colorScheme,
  });

  final String tag;
  final VoidCallback onRemove;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme
            .primaryContainer, // Use primaryContainer instead of solid primary
        borderRadius: BorderRadius.circular(30),
        // Removed heavy shadow
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding:
                const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme
                        .onPrimaryContainer, // Text matches container
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.close,
                  size: 14,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
