import 'package:flutter/material.dart';

import '../data/preset_hashtags.dart';
import '../utils/color_extensions.dart';

Future<({String name, List<String> hashtags})?> showProfileSetupModal(
  BuildContext context, {
  String? initialName,
  List<String>? initialHashtags,
  int minHashtags = 2,
  int maxHashtags = 10,
  bool lockName = false,
}) {
  return Navigator.of(context).push<({String name, List<String> hashtags})>(
    MaterialPageRoute(
      builder: (_) => _ProfileSetupPage(
        initialName: initialName,
        initialHashtags: initialHashtags,
        minHashtags: minHashtags,
        maxHashtags: maxHashtags,
        lockName: lockName,
      ),
    ),
  );
}

class _ProfileSetupPage extends StatefulWidget {
  const _ProfileSetupPage({
    this.initialName,
    this.initialHashtags,
    required this.minHashtags,
    required this.maxHashtags,
    required this.lockName,
  });

  final String? initialName;
  final List<String>? initialHashtags;
  final int minHashtags;
  final int maxHashtags;
  final bool lockName;

  @override
  State<_ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<_ProfileSetupPage> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName ?? '');
  late final Set<String> _selected = {
    if (widget.initialHashtags != null) ...widget.initialHashtags!
  };

  bool get _hasValidName => _nameController.text.trim().isNotEmpty;

  bool get _canSubmit =>
      _hasValidName && _selected.length >= widget.minHashtags;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleHashtag(String tag, bool enabled) {
    setState(() {
      if (enabled) {
        if (_selected.length < widget.maxHashtags) {
          _selected.add(tag);
        }
      } else {
        _selected.remove(tag);
      }
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      hashtags: _selected.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール設定'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lockName) ...[
                Text(
                  '表示名',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: Text(
                    _nameController.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: '表示名',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '興味のあるハッシュタグを選択してください（${widget.minHashtags}～${widget.maxHashtags}件）。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetHashtags.map((tag) {
                  final isSelected = _selected.contains(tag);
                  return FilterChip(
                    showCheckmark: false,
                    label: Text(tag),
                    selected: isSelected,
                    backgroundColor: Colors.white,
                    selectedColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                    onSelected: (value) => _toggleHashtag(tag, value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('保存して続ける'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
