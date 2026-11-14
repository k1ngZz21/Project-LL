import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class LearnLiteCard extends StatelessWidget {
  const LearnLiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor = AppColors.white,
    this.borderRadius = 16,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}
