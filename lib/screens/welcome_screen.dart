import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vib_sns/screens/name_setup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _bgPulseController;
  late AnimationController _implosionController;
  late AnimationController _shockwaveController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _logoScaleAnimation;

  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    // エントランスアニメーション
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutExpo),
      ),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );

    // 背景の脈動アニメーション
    _bgPulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _bgPulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 画面遷移アニメーション: 内破裂（吸い込み）→ 衝撃波（拡大）
    _implosionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shockwaveController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bgPulseController.dispose();
    _implosionController.dispose();
    _shockwaveController.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    setState(() => _isTransitioning = true);

    // 1. Play Implosion (particles suck into center)
    _implosionController.forward().then((_) {
      // 2. Play Shockwave (expand white circle)
      _shockwaveController.forward().then((_) {
        // 3. Navigate
        Navigator.of(context)
            .push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const NameSetupScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        )
            .then((_) {
          // 戻ってきたときにアニメーションをリセット
          if (mounted) {
            setState(() => _isTransitioning = false);
            _shockwaveController.reset();
            _implosionController.reset();
          }
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF2B705);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 動的な背景 + 画面遷移エフェクト
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _bgPulseController,
                _implosionController,
                _shockwaveController
              ]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _ThemedEffectPainter(
                    pulseValue: _bgPulseController.value,
                    implosionValue: _implosionController.value,
                    shockwaveValue: _shockwaveController.value,
                  ),
                );
              },
            ),
          ),

          // メインコンテンツ（遷移中にフェードアウト）
          if (!_isTransitioning || _implosionController.value < 1.0)
            Center(
              child: AnimatedBuilder(
                animation: _implosionController,
                builder: (context, child) {
                  // 内破裂中に少し縮小してフェードアウト
                  final val = _implosionController.value;
                  return Transform.scale(
                    scale: 1.0 - (val * 0.1),
                    child: Opacity(
                      opacity: (1.0 - val * 1.5).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // アプリロゴ（脈動付き）
                        ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Hero(
                              tag: 'app_logo',
                              child: Image.asset(
                                'assets/app_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        // スタイル付きテキスト
                        const Text(
                          'Vib SNS',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black12,
                                offset: Offset(4, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'すれ違いから始まる\n新しいつながり',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // アクションボタン
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: AnimatedBuilder(
              animation: _implosionController,
              builder: (context, child) {
                final val = _implosionController.value;
                // ボタンが内破裂と共に縮小して消える
                return Transform.scale(
                  scale: (1.0 - val).clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: (1.0 - val).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: _FuturisticButton(
                        onPressed: _onGetStarted,
                        isLoading: _isTransitioning,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuturisticButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _FuturisticButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<_FuturisticButton> createState() => _FuturisticButtonState();
}

class _FuturisticButtonState extends State<_FuturisticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _pressController.forward();
  void _handleTapUp(_) => _pressController.reverse();
  void _handleTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'はじめよう',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemedEffectPainter extends CustomPainter {
  final double pulseValue;
  final double implosionValue;
  final double shockwaveValue;

  _ThemedEffectPainter({
    required this.pulseValue,
    required this.implosionValue,
    required this.shockwaveValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final buttonCenter =
        Offset(size.width / 2, size.height - 90); // ボタンのおおよその中心

    _drawBackground(canvas, size, center);

    if (implosionValue > 0) {
      _drawImplosion(canvas, size, buttonCenter);
    }

    if (shockwaveValue > 0) {
      _drawShockwave(canvas, size, buttonCenter);
    }
  }

  void _drawBackground(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final baseRadius = size.width * 0.4;

    // Ring 1: Rotating
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulseValue * 2 * math.pi);
    canvas.drawCircle(Offset.zero, baseRadius, paint);

    // Dashes
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final dashOffset =
          Offset(math.cos(angle) * baseRadius, math.sin(angle) * baseRadius);
      canvas.drawCircle(
          dashOffset, 4, Paint()..color = Colors.white.withOpacity(0.3));
    }
    canvas.restore();

    // Ring 2: Pulsing radius
    final pulseRadius =
        baseRadius * (1.2 + 0.1 * math.sin(pulseValue * 2 * math.pi));
    paint.strokeWidth = 1.0;
    paint.color = Colors.white.withOpacity(0.1);
    canvas.drawCircle(center, pulseRadius, paint);
  }

  void _drawImplosion(Canvas canvas, Size size, Offset target) {
    final random = math.Random(1);
    final paint = Paint()..color = Colors.white;

    // Draw particles sucking IN to target
    final count = 50;
    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distanceBase = size.height * 0.8;
      // Current distance shrinks as implosionValue goes 0 -> 1
      final currentDist =
          distanceBase * (1.0 - Curves.easeInExpo.transform(implosionValue));

      // Add some spiral
      final spiralAngle = angle + (implosionValue * math.pi);

      final x = target.dx + math.cos(spiralAngle) * currentDist;
      final y = target.dy + math.sin(spiralAngle) * currentDist;

      // Opacity increases as they get closer (energy concentration)
      paint.color = Colors.white.withOpacity(implosionValue.clamp(0.0, 1.0));
      // Size stretches into lines based on speed
      canvas.drawCircle(Offset(x, y), 2 + (implosionValue * 2), paint);
    }
  }

  void _drawShockwave(Canvas canvas, Size size, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    // Expanding circle that fills screen
    final maxRadius = size.height * 1.5;
    final currentRadius = maxRadius * shockwaveValue;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _ThemedEffectPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.implosionValue != implosionValue ||
        oldDelegate.shockwaveValue != shockwaveValue;
  }
}
