import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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
  final TextEditingController _idOnlyController = TextEditingController();
  bool _loginEmailSubmitting = false;
  bool _googleSubmitting = false;
  bool _quickLoginSubmitting = false;
  bool _idOnlySubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _idOnlyController.dispose();
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
      try {
        await completeProfileSetup(
          context,
          displayName: result.name,
          username: result.username,
          hashtags: result.hashtags,
        );
      } on UsernameAlreadyTakenException catch (e) {
        if (mounted) {
          _showSnack(e.toString());
        }
        return;
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

  Future<void> _handleLoginEmailAuth() async {
    final input = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (input.isEmpty) {
      _showSnack('メールアドレスまたはユーザーIDを入力してください。');
      return;
    }
    if (password.length < 6) {
      _showSnack('パスワードは6文字以上で入力してください。');
      return;
    }

    // Determine if input is email or username
    String email = input;
    if (!input.contains('@')) {
      // Assume it's a username, look up the email from Firestore
      final username = input.startsWith('@') ? input.substring(1) : input;
      try {
        final usernameDoc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(username.toLowerCase())
            .get();
        if (!usernameDoc.exists) {
          _showSnack('このユーザーIDは登録されていません。');
          return;
        }
        final profileId = usernameDoc.data()?['profileId'] as String?;
        if (profileId == null) {
          _showSnack('ユーザー情報の取得に失敗しました。');
          return;
        }
        // Get the profile to find the email
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(profileId)
            .get();
        final profileEmail = profileDoc.data()?['email'] as String?;
        if (profileEmail == null || profileEmail.isEmpty) {
          _showSnack('このアカウントにはメールアドレスが登録されていません。');
          return;
        }
        email = profileEmail;
      } catch (e) {
        _showSnack('ユーザー情報の取得に失敗しました: $e');
        return;
      }
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

  Future<void> _handleQuickLogin() async {
    setState(() => _quickLoginSubmitting = true);
    try {
      final setup = await showProfileSetupModal(context);
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
      if (mounted) setState(() => _quickLoginSubmitting = false);
    }
  }

  /// ID-only login (no password required)
  Future<void> _handleIdOnlyLogin() async {
    final input = _idOnlyController.text.trim();
    if (input.isEmpty) {
      _showSnack('ユーザーIDを入力してください。');
      return;
    }
    setState(() => _idOnlySubmitting = true);
    try {
      final username = input.startsWith('@') ? input.substring(1) : input;
      // Look up the username in Firestore
      final usernameDoc = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      if (!usernameDoc.exists) {
        _showSnack('このユーザーIDは登録されていません。');
        return;
      }
      final profileId = usernameDoc.data()?['profileId'] as String?;
      if (profileId == null) {
        _showSnack('ユーザー情報の取得に失敗しました。');
        return;
      }
      // Load the profile and login as that user (anonymous auth + profile switch)
      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(profileId)
          .get();
      if (!profileDoc.exists) {
        _showSnack('プロフィールが見つかりません。');
        return;
      }
      if (!mounted) return;
      // Use profile setup modal with the loaded data
      final profileData = profileDoc.data()!;
      final displayName = profileData['displayName'] as String? ?? '';
      final existingUsername = profileData['username'] as String?;
      final favoriteGames = (profileData['favoriteGames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Complete profile setup with existing data
      try {
        await completeProfileSetup(
          context,
          displayName: displayName,
          username: existingUsername,
          hashtags: favoriteGames,
          existingProfileId: profileId,
        );
      } on UsernameAlreadyTakenException catch (e) {
        if (mounted) {
          _showSnack(e.toString());
        }
        return;
      } catch (error) {
        if (mounted) {
          _showSnack('ログインに失敗しました: $error');
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _showSnack('ログインに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _idOnlySubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF2B705);
    // 画面サイズを取得してレイアウト調整に使う (現在は未使用だが将来のために残すか、警告消すために削除)
    // final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 背景の装飾（オプション）
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    // ヘッダー部分
                    Column(
                      children: [
                        // イラストの代わりにアイコンを使用（またはAssetsがあればImage）
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_person_rounded,
                            size: 64,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'おかえりなさい',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ログインして続ける',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // メールアドレスまたはID入力
                    _buildModernTextField(
                      controller: _loginEmailController,
                      label: 'メールアドレスまたはユーザーID',
                      hint: 'example@email.com または @username',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // パスワード入力
                    _buildModernTextField(
                      controller: _loginPasswordController,
                      label: 'パスワード',
                      hint: 'パスワードを入力',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),

                    const SizedBox(height: 12),
                    // "Forgot Password?" のようなリンクがあればここに追加（今回は機能変更なしなのでスキップ）

                    const SizedBox(height: 32),

                    // ログインボタン
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loginEmailSubmitting
                            ? null
                            : _handleLoginEmailAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: primaryColor.withOpacity(0.4),
                        ),
                        child: _loginEmailSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'ログイン',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'または',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Google Login Button (Wrapper to match style)
                    // GoogleAuthButtonのスタイルを上書きするか、ラップして似せる
                    // ここではGoogleAuthButtonをそのまま使いつつ、周りのレイアウトで調整
                    GoogleAuthButton(
                      label: 'Googleでログイン',
                      loading: _googleSubmitting,
                      onPressed: _googleSubmitting ? null : _handleGoogleAuth,
                      // Note: GoogleAuthButtonの内部実装に依存するが、ここでは配置のみ
                    ),

                    const SizedBox(height: 32),

                    // IDでログイン（パスワード不要）セクション
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'IDでログイン（パスワード不要）',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _idOnlyController,
                          label: 'ユーザーID',
                          hint: '@username',
                          icon: Icons.alternate_email,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed:
                                _idOnlySubmitting ? null : _handleIdOnlyLogin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(
                                color: primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _idOnlySubmitting
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'IDでログイン',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 新規登録リンク
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "アカウントをお持ちでないですか？ ",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterAccountScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '新規登録',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // アカウントなしで始める（一番下に配置）
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed:
                            _quickLoginSubmitting ? null : _handleQuickLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                        ),
                        child: _quickLoginSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.grey.shade600,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'アカウントなしで始める',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '※デモ版のため「アカウントなしで始める」をおすすめします。',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ラベルを表示したい場合はコメントアウトを外す
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        */
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint, // labelの代わりにhintを使うか、labelを使うか
              labelText: label, // Floating labelにする
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: Colors.grey.shade400),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey.shade400,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
            ),
          ),
        ),
      ],
    );
  }
}
