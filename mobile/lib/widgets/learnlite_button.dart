import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'pressable.dart';

enum LearnLiteButtonVariant { filled, outlined }

class LearnLiteButton extends StatelessWidget {
  const LearnLiteButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = LearnLiteButtonVariant.filled,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final LearnLiteButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == LearnLiteButtonVariant.filled;
    final child = isLoading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: isFilled ? AppColors.white : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    final enabled = !isLoading && onPressed != null;
    final Widget button;
    if (!isFilled) {
      button = OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.white,
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.5,
          ),
          minimumSize: const Size.fromHeight(52),
        ),
        child: child,
      );
    } else {
      button = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            disabledBackgroundColor: isLoading
                ? AppColors.primary.withValues(alpha: 0.75)
                : null,
          ),
          child: child,
        ),
      );
    }
    return Pressable(enabled: enabled, child: button);
  }
}
