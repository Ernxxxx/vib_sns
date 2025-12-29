import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/profile_controller.dart';
import '../utils/profile_setup_helper.dart';
import '../utils/profile_setup_modal.dart';

class DisplayNameLoginScreen extends StatefulWidget {
  const DisplayNameLoginScreen({super.key});

  @override
  State<DisplayNameLoginScreen> createState() => _DisplayNameLoginScreenState();
}

class _DisplayNameLoginScreenState extends State<DisplayNameLoginScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stored = context.read<ProfileController>().profile.displayName;
    if (stored.trim().isNotEmpty && _controller.text.isEmpty) {
      _controller.text = stored.trim();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final setup = await showProfileSetupModal(
        context,
        initialName: _controller.text.trim(),
        lockName: true,
      );
      if (setup == null) {
        if (mounted) {
          _showSnack('表示名と最低2件のハッシュタグを選択してください。');
        }
        return;
      }
      if (!mounted) return;
      try {
        await completeProfileSetup(
          context,
          displayName: setup.name,
          username: setup.username,
          hashtags: setup.hashtags,
        );
      } on UsernameAlreadyTakenException catch (e) {
        if (mounted) {
          _showSnack(e.toString());
        }
        return;
      } catch (error) {
        if (mounted) {
          _showSnack('プロフィールの設定に失敗しました: $error');
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('表示名でログイン')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '表示名のみでログインする場合はこちらから入力してください。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: '表示名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '表示名を入力してください';
                  }
                  if (value.trim().length > 24) {
                    return '24文字以内で入力してください';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('表示名で続ける'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
