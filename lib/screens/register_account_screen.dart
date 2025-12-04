import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/auth_helpers.dart';
import '../utils/profile_setup_helper.dart';
import '../utils/profile_setup_modal.dart';
import '../widgets/google_auth_button.dart';
import 'display_name_login_screen.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _emailSubmitting = false;
  bool _googleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('正しいメールアドレスを入力してください。');
      return;
    }
    if (password.length < 6) {
      _showSnack('パスワードは6文字以上で入力してください。');
      return;
    }
    setState(() => _emailSubmitting = true);
    try {
      final credential = await linkOrSignInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await persistAuthUid(user);
        if (!mounted) return;
        final setup = await showProfileSetupModal(context);
        if (setup == null) {
          if (!mounted) return;
          _showSnack('表示名とハッシュタグを設定してください。');
          return;
        }
        if (!mounted) return;
        await completeProfileSetup(
          context,
          displayName: setup.name,
          hashtags: setup.hashtags,
        );
        if (!mounted) return;
        _showSnack('メールアドレスで登録しました。');
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_describeAuthError(error));
    } catch (error) {
      _showSnack('メール登録でエラーが発生しました: $error');
    } finally {
      if (mounted) setState(() => _emailSubmitting = false);
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() => _googleSubmitting = true);
    try {
      final credential = await signInWithGoogle();
      final user = credential?.user;
      if (user == null) {
        _showSnack('Googleアカウントでの登録がキャンセルされました。');
        return;
      }
      await persistAuthUid(user);
      if (!mounted) return;
      final setup = await showProfileSetupModal(
        context,
        initialName: user.displayName?.trim(),
      );
      if (setup == null) {
        if (!mounted) return;
        _showSnack('表示名とハッシュタグを設定してください。');
        return;
      }
      if (!mounted) return;
      await completeProfileSetup(
        context,
        displayName: setup.name,
        hashtags: setup.hashtags,
      );
      if (!mounted) return;
      _showSnack('Googleアカウントで登録しました。');
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_describeAuthError(error));
    } catch (error) {
      _showSnack('Google登録でエラーが発生しました: $error');
    } finally {
      if (mounted) setState(() => _googleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規登録'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'メールアドレスまたはGoogleアカウントで登録できます。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _emailSubmitting ? null : _handleEmailRegister,
                child: _emailSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('メールアドレスで登録'),
              ),
            ),
            const SizedBox(height: 24),
            GoogleAuthButton(
              label: 'Googleアカウントで登録',
              loading: _googleSubmitting,
              onPressed: _googleSubmitting ? null : _handleGoogleRegister,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DisplayNameLoginScreen(),
                    ),
                  );
                },
                child: const Text('その他の方法でログイン（表示名のみ）'),
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

  String _describeAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に登録されています。ログインしてください。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      default:
        return 'エラー: ${error.message ?? error.code}';
    }
  }
}
