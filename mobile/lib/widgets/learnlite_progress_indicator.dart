import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class LearnLiteProgressIndicator extends StatelessWidget {
  const LearnLiteProgressIndicator({
    required this.progress,
    this.backgroundColor = AppColors.lightPink,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(minHeight),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: minHeight,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
