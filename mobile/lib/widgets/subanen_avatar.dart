import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../core/avatar_design.dart';

/// Draws an [AvatarDesign] as a head-and-shoulders portrait. Everything is
/// vector drawing, so it works offline at any size and needs no image files.
class SubanenAvatar extends StatelessWidget {
  const SubanenAvatar({required this.design, this.size = 96, super.key});

  final AvatarDesign design;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: design.description,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: SubanenAvatarPainter(design)),
    ),
  );
}

class SubanenAvatarPainter extends CustomPainter {
  const SubanenAvatarPainter(this.design);

  final AvatarDesign design;

  bool get _female => design.gender == AvatarGender.female;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = design.backgroundColor,
    );
    _paintBackgroundMotif(canvas);
    _paintBackHair(canvas);
    _paintBody(canvas);
    _paintNeck(canvas);
    if (design.beads) _paintBeads(canvas);
    _paintHead(canvas);
    _paintFace(canvas);
    _paintFrontHair(canvas);
    if (design.headCloth) _paintHeadCloth(canvas);
    if (design.earrings) _paintEarrings(canvas);
    canvas.restore();
  }

  // Faint diamonds along the bottom of the background, echoing the woven
  // border used across LearnLite.
  void _paintBackgroundMotif(Canvas canvas) {
    final dark = design.backgroundColor.computeLuminance() < 0.3;
    final paint = Paint()
      ..color = (dark ? AppColors.gold : AppColors.primary).withValues(
        alpha: 0.12,
      );
    for (var x = 0.0; x < 1.0; x += 0.125) {
      final path = Path()
        ..moveTo(x + 0.0625, 0.06)
        ..lineTo(x + 0.1, 0.1)
        ..lineTo(x + 0.0625, 0.14)
        ..lineTo(x + 0.025, 0.1)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  Color _shade(Color color, double amount) =>
      Color.lerp(color, Colors.black, amount)!;

  // Hair that falls behind the head and shoulders.
  void _paintBackHair(Canvas canvas) {
    final hair = _fill(design.hair);
    if (_female && design.hairStyle == 0) {
      // Long, loose hair to the shoulders.
      final path = Path()
        ..moveTo(0.29, 0.42)
        ..quadraticBezierTo(0.27, 0.18, 0.5, 0.17)
        ..quadraticBezierTo(0.73, 0.18, 0.71, 0.42)
        ..lineTo(0.74, 0.8)
        ..quadraticBezierTo(0.5, 0.86, 0.26, 0.8)
        ..close();
      canvas.drawPath(path, hair);
    } else if (_female && design.hairStyle == 2) {
      // Single braid over the right shoulder.
      for (var i = 0; i < 6; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0.66 + i * 0.012, 0.56 + i * 0.065),
            width: 0.075,
            height: 0.08,
          ),
          hair,
        );
      }
      canvas.drawCircle(
        const Offset(0.73, 0.94),
        0.02,
        _fill(AppColors.primary),
      );
    } else if (!_female && design.hairStyle == 2 && !design.headCloth) {
      // Long hair gathered into a knot on top of the head.
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(0.5, 0.19),
          width: 0.12,
          height: 0.1,
        ),
        hair,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0.47, 0.225, 0.06, 0.016),
        _fill(AppColors.primary),
      );
    }
  }

  void _paintBody(Canvas canvas) {
    final shoulder = _female ? 0.16 : 0.1;
    final body = Path()
      ..moveTo(shoulder, 1.02)
      ..quadraticBezierTo(shoulder + 0.02, 0.78, 0.38, 0.74)
      ..lineTo(0.62, 0.74)
      ..quadraticBezierTo(1 - shoulder - 0.02, 0.78, 1 - shoulder, 1.02)
      ..close();
    canvas.drawPath(body, _fill(design.outfit));

    // Woven band across the chest and the sleeves' edges, clipped to the top.
    canvas.save();
    canvas.clipPath(body);
    _paintBand(canvas, top: 0.86, height: 0.07);
    canvas.restore();

    // Neckline: rounded for men, a soft V for women.
    final trim = _bandAccent(design.outfit);
    final neckline = Path();
    if (_female) {
      neckline
        ..moveTo(0.41, 0.74)
        ..lineTo(0.5, 0.83)
        ..lineTo(0.59, 0.74);
    } else {
      neckline
        ..moveTo(0.4, 0.745)
        ..quadraticBezierTo(0.5, 0.82, 0.6, 0.745);
    }
    canvas.drawPath(
      neckline,
      Paint()
        ..color = trim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  Color _bandAccent(Color outfit) =>
      outfit.computeLuminance() > 0.45 ? AppColors.primary : AppColors.gold;

  void _paintBand(Canvas canvas, {required double top, required double height}) {
    final bandBase = design.outfit.computeLuminance() < 0.08
        ? AppColors.primary
        : AppColors.darkBackground;
    final accent = _bandAccent(design.outfit);
    final rect = Rect.fromLTWH(0, top, 1, height);
    switch (design.pattern) {
      case AvatarPattern.plain:
        canvas.drawRect(
          Rect.fromLTWH(0, top + height * 0.35, 1, height * 0.3),
          _fill(accent),
        );
      case AvatarPattern.stripes:
        canvas.drawRect(rect, _fill(bandBase));
        canvas.drawRect(
          Rect.fromLTWH(0, top + height * 0.2, 1, height * 0.18),
          _fill(accent),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, top + height * 0.62, 1, height * 0.18),
          _fill(accent),
        );
      case AvatarPattern.zigzag:
        canvas.drawRect(rect, _fill(bandBase));
        const tile = 0.06;
        final up = _fill(accent);
        final down = _fill(
          accent == AppColors.gold ? AppColors.primary : AppColors.gold,
        );
        for (var x = 0.0; x < 1.0; x += tile) {
          canvas.drawPath(
            Path()
              ..moveTo(x, top + height)
              ..lineTo(x + tile / 4, top + height * 0.35)
              ..lineTo(x + tile / 2, top + height)
              ..close(),
            up,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x + tile / 2, top)
              ..lineTo(x + tile * 0.75, top + height * 0.65)
              ..lineTo(x + tile, top)
              ..close(),
            down,
          );
        }
      case AvatarPattern.diamond:
        canvas.drawRect(rect, _fill(bandBase));
        const tile = 0.08;
        final paint = _fill(accent);
        final dot = _fill(
          accent == AppColors.gold ? AppColors.primary : AppColors.gold,
        );
        final mid = top + height / 2;
        for (var x = 0.0; x < 1.0; x += tile) {
          final cx = x + tile / 2;
          canvas.drawPath(
            Path()
              ..moveTo(cx, top + height * 0.08)
              ..lineTo(cx + tile * 0.42, mid)
              ..lineTo(cx, top + height * 0.92)
              ..lineTo(cx - tile * 0.42, mid)
              ..close(),
            paint,
          );
          canvas.drawCircle(Offset(cx, mid), height * 0.14, dot);
        }
    }
  }

  void _paintNeck(Canvas canvas) {
    final neck = RRect.fromRectAndCorners(
      const Rect.fromLTWH(0.43, 0.58, 0.14, 0.18),
      bottomLeft: const Radius.circular(0.05),
      bottomRight: const Radius.circular(0.05),
    );
    canvas.drawRRect(neck, _fill(_shade(design.skin, 0.12)));
  }

  void _paintBeads(Canvas canvas) {
    const colors = [AppColors.primary, AppColors.gold, AppColors.darkBackground];
    const count = 11;
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final angle = math.pi * (0.15 + 0.7 * t);
      final center = Offset(0.5 + 0.12 * math.cos(angle), 0.73 + 0.07 * math.sin(angle));
      canvas.drawCircle(center, 0.016, _fill(colors[i % colors.length]));
      canvas.drawCircle(
        center,
        0.016,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.003,
      );
    }
  }

  void _paintHead(Canvas canvas) {
    final skin = _fill(design.skin);
    // Ears.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.325, 0.45), width: 0.06, height: 0.09),
      skin,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.675, 0.45), width: 0.06, height: 0.09),
      skin,
    );
    final width = _female ? 0.33 : 0.35;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.5, 0.43), width: width, height: 0.4),
      skin,
    );
  }

  void _paintFace(Canvas canvas) {
    final dark = _fill(const Color(0xFF231A14));
    // Eyes with a small highlight.
    for (final x in [0.44, 0.56]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 0.455), width: 0.032, height: 0.04),
        dark,
      );
      canvas.drawCircle(Offset(x + 0.006, 0.448), 0.006, _fill(Colors.white));
    }
    // Eyebrows.
    final brow = Paint()
      ..color = _shade(design.hair, 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _female ? 0.009 : 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0.415, 0.41)
        ..quadraticBezierTo(0.44, 0.395, 0.465, 0.405),
      brow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.535, 0.405)
        ..quadraticBezierTo(0.56, 0.395, 0.585, 0.41),
      brow,
    );
    // Nose.
    canvas.drawPath(
      Path()
        ..moveTo(0.5, 0.48)
        ..quadraticBezierTo(0.487, 0.515, 0.5, 0.522),
      Paint()
        ..color = _shade(design.skin, 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.008
        ..strokeCap = StrokeCap.round,
    );
    // Cheeks.
    final blush = _fill(AppColors.primary.withValues(alpha: _female ? 0.18 : 0.1));
    canvas.drawCircle(const Offset(0.41, 0.52), 0.028, blush);
    canvas.drawCircle(const Offset(0.59, 0.52), 0.028, blush);
    // Smile.
    canvas.drawPath(
      Path()
        ..moveTo(0.46, 0.555)
        ..quadraticBezierTo(0.5, 0.59, 0.54, 0.555),
      Paint()
        ..color = _female ? AppColors.redDark : _shade(design.skin, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintFrontHair(Canvas canvas) {
    if (design.headCloth) {
      // The head cloth covers the top of the head; only the sides show.
      _paintSideHair(canvas);
      return;
    }
    final hair = _fill(design.hair);
    if (_female) {
      // Crown with a centre parting, shared by all three styles.
      final crown = Path()
        ..moveTo(0.325, 0.44)
        ..quadraticBezierTo(0.31, 0.2, 0.5, 0.21)
        ..quadraticBezierTo(0.69, 0.2, 0.675, 0.44)
        ..quadraticBezierTo(0.64, 0.3, 0.5, 0.29)
        ..quadraticBezierTo(0.36, 0.3, 0.325, 0.44)
        ..close();
      canvas.drawPath(crown, hair);
      if (design.hairStyle == 1) {
        canvas.drawCircle(const Offset(0.5, 0.18), 0.075, hair);
        canvas.drawRect(
          const Rect.fromLTWH(0.465, 0.235, 0.07, 0.018),
          _fill(AppColors.gold),
        );
      }
      return;
    }
    switch (design.hairStyle) {
      case 1:
        // Wavy: scalloped hairline.
        final wavy = Path()..moveTo(0.33, 0.42);
        wavy.quadraticBezierTo(0.3, 0.2, 0.5, 0.2);
        wavy.quadraticBezierTo(0.7, 0.2, 0.67, 0.42);
        for (var i = 0; i < 5; i++) {
          final x0 = 0.67 - i * 0.068;
          wavy.quadraticBezierTo(x0 - 0.034, 0.27, x0 - 0.068, 0.33);
        }
        wavy.close();
        canvas.drawPath(wavy, hair);
      default:
        // Short (and the top of long tied hair).
        final short = Path()
          ..moveTo(0.325, 0.42)
          ..quadraticBezierTo(0.31, 0.21, 0.5, 0.21)
          ..quadraticBezierTo(0.69, 0.21, 0.675, 0.42)
          ..quadraticBezierTo(0.66, 0.31, 0.56, 0.3)
          ..quadraticBezierTo(0.45, 0.33, 0.36, 0.3)
          ..quadraticBezierTo(0.33, 0.33, 0.325, 0.42)
          ..close();
        canvas.drawPath(short, hair);
    }
  }

  void _paintSideHair(Canvas canvas) {
    final hair = _fill(design.hair);
    canvas.drawRect(const Rect.fromLTWH(0.325, 0.33, 0.03, 0.1), hair);
    canvas.drawRect(const Rect.fromLTWH(0.645, 0.33, 0.03, 0.1), hair);
  }

  void _paintHeadCloth(Canvas canvas) {
    final cloth = Path()
      ..moveTo(0.315, 0.38)
      ..quadraticBezierTo(0.3, 0.17, 0.5, 0.17)
      ..quadraticBezierTo(0.7, 0.17, 0.685, 0.38)
      ..quadraticBezierTo(0.5, 0.33, 0.315, 0.38)
      ..close();
    canvas.drawPath(cloth, _fill(design.outfit));
    canvas.save();
    canvas.clipPath(cloth);
    _paintBand(canvas, top: 0.31, height: 0.06);
    canvas.restore();
    // Knot and tail at the side.
    final knot = _fill(_shade(design.outfit, 0.2));
    canvas.drawCircle(const Offset(0.69, 0.33), 0.035, knot);
    canvas.drawPath(
      Path()
        ..moveTo(0.69, 0.33)
        ..quadraticBezierTo(0.78, 0.38, 0.76, 0.47)
        ..lineTo(0.72, 0.45)
        ..quadraticBezierTo(0.73, 0.39, 0.68, 0.36)
        ..close(),
      knot,
    );
  }

  void _paintEarrings(Canvas canvas) {
    final gold = _fill(AppColors.gold);
    final ring = Paint()
      ..color = AppColors.goldDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.004;
    for (final x in [0.322, 0.678]) {
      canvas.drawCircle(Offset(x, 0.505), 0.018, gold);
      canvas.drawCircle(Offset(x, 0.505), 0.018, ring);
    }
  }

  @override
  bool shouldRepaint(SubanenAvatarPainter oldDelegate) =>
      oldDelegate.design != design;
}
