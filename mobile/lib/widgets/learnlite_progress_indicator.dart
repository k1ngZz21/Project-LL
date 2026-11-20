import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'pressable.dart';

/// A rounded progress bar that animates to its value.
class LearnLiteProgressIndicator extends StatelessWidget {
  const LearnLiteProgressIndicator({
    required this.progress,
    this.backgroundColor = AppColors.creamSecondary,
    this.color = AppColors.primary,
    this.minHeight = 8,
    super.key,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final Color backgroundColor;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    Widget bar(double value) => ClipRRect(
      borderRadius: BorderRadius.circular(minHeight),
      child: LinearProgressIndicator(
        value: value,
        minHeight: minHeight,
        color: color,
        backgroundColor: backgroundColor,
        borderRadius: BorderRadius.circular(minHeight),
      ),
    );
    if (reduceMotionOf(context)) return bar(progress);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => bar(value),
    );
  }
}

/// A circular score ring with the value drawn in the centre.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    required this.progress,
    required this.center,
    this.size = 124,
    this.color = AppColors.primary,
    this.trackColor = AppColors.creamSecondary,
    super.key,
  });

  final double progress;
  final Widget center;
  final double size;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    Widget ring(double value) => SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: trackColor,
            ),
          ),
          center,
        ],
      ),
    );
    if (reduceMotionOf(context)) return ring(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ring(value),
    );
  }
}
