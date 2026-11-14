import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class LearnLiteBrandMark extends StatelessWidget {
  const LearnLiteBrandMark({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'LearnLite logo',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, Radius.circular(size.width * 0.19)),
      Paint()..color = AppColors.primary,
    );

    final center = Offset(size.width / 2, size.height / 2);
    void diamond(double radius, Color color) {
      final path = Path()
        ..moveTo(center.dx, center.dy - radius)
        ..lineTo(center.dx + radius, center.dy)
        ..lineTo(center.dx, center.dy + radius)
        ..lineTo(center.dx - radius, center.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    diamond(size.width * 0.35, AppColors.darkBackground);
    diamond(size.width * 0.195, AppColors.gold);
    diamond(size.width * 0.078, AppColors.primary);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
