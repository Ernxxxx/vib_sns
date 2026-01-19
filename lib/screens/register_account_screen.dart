import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/auth_helpers.dart';
import '../utils/profile_setup_helper.dart';
import '../utils/profile_setup_modal.dart';
import '../widgets/google_auth_button.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  bool _emailSubmitting = false;
  bool _googleSubmitting = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  // 許可された記号: ~ ! @ # $ % ^ & * ( ) _ + { } [ ] \ ? : " ; ' , . / = -
  static final RegExp _validPasswordChars =
      RegExp(r'^[a-zA-Z0-9~!@#$%^&*()_+\}\{\[\]\\?:";' r"'" r',./=\-]+$');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// パスワードバリデーション
  /// 条件:
  /// - 6文字以上
  /// - 半角英数字と許可された記号のみ
  /// - スペース、全角文字、その他の無効な文字を含まない
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'パスワードを入力してください。';
    }
    if (password.length < 6) {
      return 'パスワードは6文字以上で入力してください。';
    }
    // スペースのチェック
    if (password.contains(' ') || password.contains('　')) {
      return 'パスワードにスペースを含めることはできません。';
    }
    // 許可された文字のみかチェック
    if (!_validPasswordChars.hasMatch(password)) {
      return 'パスワードは半角英数字と許可された記号のみ使用できます。\n(利用可能な記号: ~ ! @ # \$ % ^ & * ( ) _ + { } [ ] \\ ? : " ; \' , . / = -)';
    }
    return null;
  }

  Future<void> _handleEmailRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnack('正しいメールアドレスを入力してください。');
      return;
    }

    // パスワードバリデーション
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      _showSnack(passwordError);
      return;
    }

    // パスワード確認チェック
    if (password != passwordConfirm) {
      _showSnack('パスワードが一致しません。再度ご確認ください。');
      return;
    }
    setState(() => _emailSubmitting = true);
    try {
      final auth = FirebaseAuth.instance;

      // 匿名ユーザーがいる場合はサインアウト
      if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
        await auth.signOut();
      }

      UserCredential credential;
      try {
        // 新規登録を試行
        credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // 既に登録済みの場合はログイン
          _showSnack('このメールアドレスは既に登録されています。ログインを試みます...');
          credential = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

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
        debugPrint('RegisterAccountScreen: setup.username=${setup.username}');
        try {
          await completeProfileSetup(
            context,
            displayName: setup.name,
            username: setup.username,
            hashtags: setup.hashtags,
          );
        } on UsernameAlreadyTakenException catch (error) {
          if (!mounted) return;
          _showSnack(error.toString());
          return;
        }
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

      // パスワード設定ダイアログを表示
      if (!mounted) return;
      final password = await _showPasswordSetupDialog(user.email);
      if (password == null) {
        _showSnack('パスワードの設定がキャンセルされました。');
        // ユーザーをサインアウト
        await FirebaseAuth.instance.signOut();
        return;
      }

      // メール/パスワード認証をリンク
      if (user.email != null) {
        try {
          final emailCredential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
          await user.linkWithCredential(emailCredential);
        } catch (e) {
          debugPrint('Failed to link email credential: $e');
          // リンク失敗してもGoogle認証は成功しているので続行
        }
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
      try {
        await completeProfileSetup(
          context,
          displayName: setup.name,
          username: setup.username,
          hashtags: setup.hashtags,
        );
      } on UsernameAlreadyTakenException catch (error) {
        if (!mounted) return;
        _showSnack(error.toString());
        return;
      }
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

  Future<String?> _showPasswordSetupDialog(String? email) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    String? errorMessage;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('パスワードを設定'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email != null) ...[
                  Text('メールアドレス: $email', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'メールアドレスでもログインできるようにパスワードを設定してください。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    border: const OutlineInputBorder(),
                    helperText: '6文字以上、半角英数字と記号',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'パスワード（確認用）',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                final confirm = confirmController.text;

                // バリデーション
                final validationError = _validatePassword(password);
                if (validationError != null) {
                  setDialogState(() => errorMessage = validationError);
                  return;
                }
                if (password != confirm) {
                  setDialogState(() => errorMessage = 'パスワードが一致しません。');
                  return;
                }

                Navigator.of(context).pop(password);
              },
              child: const Text('設定する'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF2B705);
    final theme = Theme.of(context);

    // バリデーションエラーなどでスナックバーを表示するためにScaffoldが必要
    // 既存のScaffoldMessengerロジックは _showSnack で context を使うため問題なし

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('新規登録'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // ヘッダーテキスト
              Text(
                'はじめましょう！',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'アカウントを作成して、近くの人とつながりましょう。',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // メールアドレス
              _buildModernTextField(
                controller: _emailController,
                label: 'メールアドレス',
                hint: 'example@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // パスワード
              _buildModernTextField(
                controller: _passwordController,
                label: 'パスワード',
                hint: '6文字以上',
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscurePassword,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),

              // パスワード確認
              _buildModernTextField(
                controller: _passwordConfirmController,
                label: 'パスワード（確認）',
                hint: 'パスワードを再入力',
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: _obscurePasswordConfirm,
                onToggleObscure: () => setState(
                    () => _obscurePasswordConfirm = !_obscurePasswordConfirm),
              ),

              const SizedBox(height: 12),
              Text(
                '使用可能な記号: ~ ! @ # \$ % ^ & * ( ) _ + { } [ ] \\ ? : " ; \' , . / = -',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // 登録ボタン
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _emailSubmitting ? null : _handleEmailRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                  child: _emailSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          '登録する',
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

              // Google登録
              GoogleAuthButton(
                label: 'Googleで登録',
                loading: _googleSubmitting,
                onPressed: _googleSubmitting ? null : _handleGoogleRegister,
              ),

              const SizedBox(height: 32),

              // ログインへのリンク
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "すでにアカウントをお持ちですか？ ",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // 基本的にpopで戻ればLogin画面のはず
                    },
                    child: const Text(
                      'ログイン',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
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
        /*
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
              hintText: hint,
              labelText: label,
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
