import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_interaction_service.dart';
import '../state/emotion_map_manager.dart';
import '../state/encounter_manager.dart';
import '../state/local_profile_loader.dart';
import '../state/notification_manager.dart';
import '../state/profile_controller.dart';
import '../state/timeline_manager.dart';
import '../utils/auth_helpers.dart';

class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({super.key});

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _nameSubmitting = false;
  bool _registerEmailSubmitting = false;
  bool _loginEmailSubmitting = false;
  bool _googleSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleNameSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _nameSubmitting = true);
    final name = _nameController.text.trim();
    try {
      await LocalProfileLoader.saveDisplayName(name);
      final updated = await LocalProfileLoader.loadOrCreate();

      // Ensure user is authenticated before proceeding
      User? user = await ensureAnonymousAuth();

      if (user != null) {
        // Save authUid to the profile document
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(updated.id)
            .set(
          {
            'authUid': user.uid,
          },
          SetOptions(merge: true),
        );

        // Bootstrap the full profile to Firestore
        if (!mounted) return;
        final interactionService = context.read<ProfileInteractionService>();
        await interactionService.bootstrapProfile(updated);
      }
      if (!mounted) return;
      final manager = context.read<EncounterManager>();
      final profileController = context.read<ProfileController>();
      final notificationManager = context.read<NotificationManager>();
      final timelineManager = context.read<TimelineManager>();
      final emotionMapManager = context.read<EmotionMapManager>();

      // Resume managers after successful authentication and profile setup
      notificationManager.resumeAfterLogin(updated);
      timelineManager.resumeAfterLogin();
      emotionMapManager.resumeAfterLogin();
      manager.resumeProfileSync();

      await manager.switchLocalProfile(updated);
      unawaited(manager.start());
      profileController.updateProfile(updated, needsSetup: false);
    } finally {
      if (mounted) setState(() => _nameSubmitting = false);
    }
  }

  Future<void> _handleRegisterEmailAuth() async {
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('正しいメールアドレスを入力してください。');
      return;
    }
    if (password.length < 6) {
      _showSnack('パスワードは6文字以上で入力してください。');
      return;
    }
    setState(() => _registerEmailSubmitting = true);
    try {
      final userCredential =
          await _signInOrLinkWithEmail(email: email, password: password);
      final user = userCredential.user;
      if (user == null) {
        _showSnack('メールアドレス認証に失敗しました。時間をおいて再度お試しください。');
        return;
      }
      await _persistAuthUid(user);
      if (mounted) {
        _showSnack('メールアドレスで認証しました。');
      }
    } on FirebaseAuthException catch (error) {
      _showSnack(_describeAuthError(error));
    } catch (error) {
      _showSnack('メールアドレス認証でエラーが発生しました: $error');
    } finally {
      if (mounted) {
        setState(() => _registerEmailSubmitting = false);
      }
    }
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
      await _persistAuthUid(user);
      if (mounted) {
        _showSnack('Googleアカウントで認証しました。');
      }
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

  Future<UserCredential> _signInOrLinkWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    final currentUser = auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        return await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'email-already-in-use') {
          await auth.signOut();
          return await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        rethrow;
      }
    }
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
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
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user != null) {
        await _persistAuthUid(user);
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

  Future<void> _continueWithStoredName() async {
    final profile = context.read<ProfileController>().profile;
    final storedName = profile.displayName.trim();
    if (storedName.isEmpty) {
      _showSnack('保存された名前がありません。登録タブで名前を入力してください。');
      return;
    }
    _nameController.text = storedName;
    await _handleNameSubmit();
  }

  Future<void> _persistAuthUid(User user) async {
    final localProfile = await LocalProfileLoader.loadOrCreate();
    await FirebaseFirestore.instance
        .collection('profiles')
        .doc(localProfile.id)
        .set({'authUid': user.uid}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storedName = context.watch<ProfileController>().profile.displayName;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u306f\u3058\u3081\u307e\u3057\u3066',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u65b0\u898f\u767b\u9332\u3068\u30ed\u30b0\u30a4\u30f3\u3092\u307f\u3084\u3059\u304f\u5207\u308a\u66ff\u3048\u307e\u3059\u3002',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TabBar(
                  labelColor: theme.colorScheme.primary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: '登録'),
                    Tab(text: 'ログイン'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildRegisterTab(theme),
                      _buildLoginTab(theme, storedName),
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

  Widget _buildRegisterTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '表示名を登録して新しいプロフィールを作成しましょう。後から編集できます。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: '\u8868\u793a\u540d',
                hintText: '\u4f8b: \u3072\u306a\u305f',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '\u540d\u524d\u3092\u5165\u529b\u3057\u3066\u304f\u3060\u3055\u3044';
                }
                if (value.trim().length > 24) {
                  return '24\u6587\u5b57\u4ee5\u5185\u3067\u5165\u529b\u3057\u3066\u304f\u3060\u3055\u3044';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameSubmitting ? null : _handleNameSubmit,
              child: _nameSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('\u767b\u9332\u3059\u308b'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'メールアドレスで登録',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildEmailFields(
            emailController: _registerEmailController,
            passwordController: _registerPasswordController,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed:
                  _registerEmailSubmitting ? null : _handleRegisterEmailAuth,
              child: _registerEmailSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('メールアドレスで登録'),
            ),
          ),
          const SizedBox(height: 16),
          _buildGoogleButton(label: 'Googleアカウントで登録'),
        ],
      ),
    );
  }

  Widget _buildLoginTab(ThemeData theme, String storedName) {
    final hasStoredName = storedName.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '既に登録済みの方はこちらからログインしてください。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '保存された名前で続ける',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasStoredName ? storedName : '保存された名前がありません。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: hasStoredName && !_nameSubmitting
                          ? _continueWithStoredName
                          : null,
                      child: _nameSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('この名前で続ける'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'メールアドレスでログイン',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
              onPressed:
                  _loginEmailSubmitting ? null : _handleLoginEmailAuth,
              child: _loginEmailSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ログインする'),
            ),
          ),
          const SizedBox(height: 16),
          _buildGoogleButton(label: 'Googleアカウントでログイン'),
        ],
      ),
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
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'パスワード',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton({required String label}) {
    final isLoading = _googleSubmitting;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : _handleGoogleAuth,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
