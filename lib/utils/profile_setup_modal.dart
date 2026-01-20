import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/hashtag_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<({String name, String? username, List<String> hashtags})?>
    showProfileSetupModal(
  BuildContext context, {
  String? initialName,
  String? initialUsername,
  List<String>? initialHashtags,
  int minHashtags = 2,
  int maxHashtags = 10,
  bool lockName = false,
}) {
  return Navigator.of(context)
      .push<({String name, String? username, List<String> hashtags})>(
    MaterialPageRoute(
      builder: (_) => _ProfileSetupPage(
        initialName: initialName,
        initialUsername: initialUsername,
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
    this.initialUsername,
    this.initialHashtags,
    required this.minHashtags,
    required this.maxHashtags,
    required this.lockName,
  });

  final String? initialName;
  final String? initialUsername;
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
  late final TextEditingController _usernameController =
      TextEditingController(text: widget.initialUsername ?? '');
  late final Set<String> _selected = {
    ...?widget.initialHashtags,
  };
  String? _usernameError;
  bool _checkingUsername = false;
  Timer? _debounceTimer;

  bool get _hasValidName => _nameController.text.trim().isNotEmpty;

  bool get _hasValidUsername {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return false;
    return Profile.validateUsername(username) == null;
  }

  bool get _canSubmit =>
      _hasValidName &&
      _hasValidUsername &&
      _selected.length >= widget.minHashtags &&
      _usernameError == null &&
      !_checkingUsername;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _validateUsername(String value) {
    // まずローカルバリデーション
    final localError = Profile.validateUsername(value);
    if (localError != null) {
      setState(() {
        _usernameError = localError;
        _checkingUsername = false;
      });
      return;
    }

    // デバウンスしてFirestoreチェック
    _debounceTimer?.cancel();
    setState(() => _checkingUsername = true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final normalizedUsername = value.toLowerCase().trim();
      try {
        final query = await FirebaseFirestore.instance
            .collection('profiles')
            .where('username', isEqualTo: normalizedUsername)
            .limit(1)
            .get();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _checkingUsername = false;
          if (query.docs.isNotEmpty) {
            _usernameError = l10n?.usernameAlreadyTaken(normalizedUsername) ??
                'このユーザーIDは既に使用されています';
          } else {
            _usernameError = null;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameError = null; // エラー時は許可
        });
      }
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final username = Profile.normalizeUsername(_usernameController.text);
    Navigator.of(context).pop((
      name: _nameController.text.trim(),
      username: username,
      hashtags: _selected.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.profileSetupTitle ?? 'プロフィール設定'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lockName) ...[
                Text(
                  l10n?.displayName ?? '表示名',
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
                  decoration: InputDecoration(
                    labelText: l10n?.displayName ?? '表示名',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              // Username field
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n?.userIdRequiredLabel ?? 'ユーザーID（必須）',
                  hintText: '@username',
                  prefixText: '@',
                  border: const OutlineInputBorder(),
                  errorText: _usernameError,
                  helperText: l10n?.usernameHelperText ?? '英数字とアンダースコア、3〜20文字',
                ),
                onChanged: _validateUsername,
              ),
              const SizedBox(height: 24),
              HashtagPicker(
                selectedTags: _selected,
                onChanged: (newTags) {
                  setState(() {
                    _selected.clear();
                    _selected.addAll(newTags);
                  });
                },
                minSelection: widget.minHashtags,
                maxSelection: widget.maxHashtags,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(l10n?.saveAndContinue ?? '保存して続ける'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
