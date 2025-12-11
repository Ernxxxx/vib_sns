import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/auth_helpers.dart';
import '../utils/profile_setup_helper.dart';
import '../utils/profile_setup_modal.dart';
import '../widgets/google_auth_button.dart';
import 'register_account_screen.dart';

class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({super.key});

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  bool _loginEmailSubmitting = false;
  bool _googleSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _googleSubmitting = true);
    try {
      final credential = await signInWithGoogle();
      final user = credential?.user;
      if (user == null) {
        _showSnack('Googleアカウントでのログインがキャンセルされました。');
        return;
      }
      await persistAuthUid(user);
      if (!mounted) return;
      final result = await showProfileSetupModal(
        context,
        initialName: user.displayName?.trim(),
      );
      if (result == null || !mounted) {
        _showSnack('表示名とハッシュタグの設定を完了してください。');
        return;
      }
      await completeProfileSetup(
        context,
        displayName: result.name,
        hashtags: result.hashtags,
      );
    } on FirebaseAuthException catch (error) {
      _showSnack(_describeAuthError(error));
    } catch (error) {
      _showSnack('Google認証でエラーが発生しました: $error');
    } finally {
      if (mounted) {
        setState(() => _googleSubmitting = false);
      }
    }
  }

  Future<void> _handleLoginEmailAuth() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('正しいメールアドレスを入力してください。');
      return;
    }
    if (password.length < 6) {
      _showSnack('パスワードは6文字以上で入力してください。');
      return;
    }
    setState(() => _loginEmailSubmitting = true);
    try {
      final auth = FirebaseAuth.instance;

      // 匿名ユーザーがいる場合はサインアウト
      if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
        await auth.signOut();
      }

      final credential = await auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = credential.user;
      if (user != null) {
        await persistAuthUid(user);
        _showSnack('メールアドレスでログインしました。');
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_describeAuthError(error));
    } catch (error) {
      _showSnack('メールログインでエラーが発生しました: $error');
    } finally {
      if (mounted) {
        setState(() => _loginEmailSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _describeAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に登録されています。パスワードを入力してログインしてください。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'user-disabled':
        return 'このアカウントは無効になっています。';
      default:
        return 'メール認証エラー: ${error.message ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ログイン',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildEmailLoginSection(theme),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('または', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              GoogleAuthButton(
                label: 'Googleでログイン',
                loading: _googleSubmitting,
                onPressed: _googleSubmitting ? null : _handleGoogleAuth,
              ),
              const SizedBox(height: 48),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterAccountScreen(),
                      ),
                    );
                  },
                  child: const Text('初めての方はこちら（新規登録）'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailLoginSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'メールアドレスでログイン',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildEmailFields(
          emailController: _loginEmailController,
          passwordController: _loginPasswordController,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loginEmailSubmitting ? null : _handleLoginEmailAuth,
            child: _loginEmailSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('メールでログイン'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailFields({
    required TextEditingController emailController,
    required TextEditingController passwordController,
  }) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'パスワード',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
      ],
    );
  }
}
