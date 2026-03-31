import 'package:flutter/material.dart';

/// NAHAM logo: minimalist face with fork (left eye), spoon (right eye), smiling mouth with tongue.
/// Rendered as line art; adapts to theme or optional color.
class AppLogo extends StatelessWidget {
  final double size;
  final bool usePrimaryColor;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 80,
    this.usePrimaryColor = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ??
        (usePrimaryColor ? Theme.of(context).colorScheme.primary : Colors.black87);
    return CustomPaint(
      size: Size(size, size),
      painter: _NahamLogoPainter(color: resolvedColor),
    );
  }
}

class _NahamLogoPainter extends CustomPainter {
  final Color color;

  _NahamLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final scale = size.width / 80;

    // Left eye: fork (3 tines up, handle down)
    final forkLeft = size.width * 0.28;
    final forkY = size.height * 0.35;
    final tineH = 8 * scale;
    final gap = 4 * scale;
    canvas.drawLine(Offset(forkLeft, forkY - tineH), Offset(forkLeft, forkY + 14 * scale), paint);
    canvas.drawLine(Offset(forkLeft - gap, forkY - tineH), Offset(forkLeft - gap, forkY), paint);
    canvas.drawLine(Offset(forkLeft + gap, forkY - tineH), Offset(forkLeft + gap, forkY), paint);

    // Right eye: spoon (oval bowl up, handle down)
    final spoonLeft = size.width * 0.52;
    final spoonY = size.height * 0.38;
    canvas.drawOval(Rect.fromCenter(center: Offset(spoonLeft, spoonY - 6 * scale), width: 12 * scale, height: 10 * scale), paint);
    canvas.drawLine(Offset(spoonLeft, spoonY + 4 * scale), Offset(spoonLeft, spoonY + 14 * scale), paint);

    // Smile + tongue
    final mouthY = size.height * 0.68;
    final mouthW = size.width * 0.35;
    final path = Path();
    path.moveTo(center.dx - mouthW * 0.5, mouthY);
    path.quadraticBezierTo(center.dx, mouthY + 10 * scale, center.dx + mouthW * 0.5, mouthY);
    canvas.drawPath(path, paint);
    final tonguePath = Path();
    tonguePath.moveTo(center.dx, mouthY + 2 * scale);
    tonguePath.quadraticBezierTo(center.dx + 4 * scale, mouthY + 8 * scale, center.dx, mouthY + 6 * scale);
    canvas.drawPath(tonguePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
