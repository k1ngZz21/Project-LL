import 'package:flutter/material.dart';

import '../app/app_colors.dart';

/// The woven diamond border used under every LearnLite app bar
/// (`AppBar(bottom: weaveAppBarBottom)`).
const weaveAppBarBottom = PreferredSize(
  preferredSize: Size.fromHeight(10),
  child: DecorativeBorder(height: 10),
);

class DecorativeBorder extends StatelessWidget {
  const DecorativeBorder({
    this.color = AppColors.gold,
    this.height = 10,
    super.key,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Decorative geometric border',
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _GeometricBorderPainter(color),
      ),
    );
  }
}

class _GeometricBorderPainter extends CustomPainter {
  const _GeometricBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.darkBackground,
    );

    final red = Paint()..color = AppColors.primary;
    final accent = Paint()..color = color;
    const tileWidth = 24.0;
    for (var left = 0.0; left < size.width; left += tileWidth) {
      final triangles = Path()
        ..moveTo(left, size.height)
        ..lineTo(left + 6, 4)
        ..lineTo(left + 12, size.height)
        ..close()
        ..moveTo(left + 12, 0)
        ..lineTo(left + 18, 6)
        ..lineTo(left + tileWidth, 0)
        ..close();
      canvas.drawPath(triangles, red);

      final diamond = Path()
        ..moveTo(left + 12, 2.2)
        ..lineTo(left + 14.8, 5)
        ..lineTo(left + 12, 7.8)
        ..lineTo(left + 9.2, 5)
        ..close();
      canvas.drawPath(diamond, accent);
      canvas.drawCircle(Offset(left, 2), 1.2, accent);
      canvas.drawCircle(Offset(left + tileWidth, 2), 1.2, accent);
    }
  }

  @override
  bool shouldRepaint(_GeometricBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
