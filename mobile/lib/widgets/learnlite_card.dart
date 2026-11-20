import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../app/app_theme.dart';
import 'pressable.dart';

/// The LearnLite surface: a rounded card with a hairline border and a soft,
/// warm shadow. Tinted or dark cards drop the shadow so they sit flat.
///
/// When [onTap] is set the whole card is a touch target with ripple and a
/// subtle press scale.
class LearnLiteCard extends StatelessWidget {
  const LearnLiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor = AppColors.white,
    this.borderRadius = AppRadius.lg,
    this.borderColor,
    this.onTap,
    this.elevated,
    this.gradient,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// Defaults to true for white cards and false for tinted ones.
  final bool? elevated;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final isWhite = backgroundColor == AppColors.white && gradient == null;
    final hasShadow = elevated ?? isWhite;
    final radius = BorderRadius.circular(borderRadius);
    final isDark = backgroundColor.computeLuminance() < 0.2;
    final side = borderColor ??
        (isDark || gradient != null
            ? Colors.transparent
            : isWhite
            ? AppColors.borderSoft
            : AppColors.border.withValues(alpha: 0.6));

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),
          child: content,
        ),
      );
    }

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? backgroundColor : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: side),
        boxShadow: hasShadow ? AppShadows.card : null,
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );

    return onTap == null ? card : Pressable(child: card);
  }
}
