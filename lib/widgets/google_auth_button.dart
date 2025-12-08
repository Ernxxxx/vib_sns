import 'package:flutter/material.dart';

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _GoogleLogoPainter(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F1F1F),
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Radius adjusted for stroke width to fit nicely
    final radius = (size.width / 2) - 2;
    final strokeWidth = 3.5;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Butt cap for sharper segment transitions

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Drawing segments in Counter-Clockwise (CCW) direction starting from the top-right gap.
    // 0 is East (Right). Negative angle is North (CCW).

    // 1. Red (Top)
    // Starts at approx -45 degrees (-0.8 rad) and sweeps Left/Top side.
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -0.8, -1.8, false, paint);
    // Ends at -2.6 rad (~ -150 deg)

    // 2. Yellow (Left-Upper)
    // Starts where Red ended
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -2.6, -1.3, false, paint);
    // Ends at -3.9 rad (~ -223 deg)

    // 3. Green (Bottom)
    // Starts where Yellow ended
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -3.9, -1.5, false, paint);
    // Ends at -5.4 rad (~ -309 deg, or +51 deg)

    // 4. Blue (Bottom-Right Arc + Bar)
    paint.color = const Color(0xFF4285F4);

    // Blue Arc: from Green end (+51 deg) UP to the horizontal bar (0 deg).
    // Start at -5.4 (which is 0.88 rad), sweep CCW to roughly 0 (or slightly below).
    // Let's sweep to -0.1 to leave room for bar connector? Or just 0.
    canvas.drawArc(rect, -5.4, -0.88, false, paint);

    // Blue Bar (Horizontal)
    // Draws from center to right edge (overwriting the start of the arc essentially)
    paint.style = PaintingStyle.fill;
    // Bar thickness matches stroke width roughly
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - (strokeWidth / 2), radius + 2,
          strokeWidth),
      paint,
    );

    // Optional: Blue triangle connector?
    // Standard G has the bar connecting firmly. The rect works well.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
