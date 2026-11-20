import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import 'pressable.dart';

enum AnswerOptionState { idle, selected, correct, incorrect, disabled }

/// One multiple-choice answer: a letter badge, the answer text and, after
/// checking, a correct/incorrect mark. Colour changes animate.
class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    required this.index,
    required this.label,
    required this.state,
    required this.onTap,
    super.key,
  });

  final int index;
  final String label;
  final AnswerOptionState state;
  final VoidCallback? onTap;

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final (background, border, badgeBg, badgeFg, textColor) = switch (state) {
      AnswerOptionState.selected => (
        AppColors.lightPink,
        AppColors.primary,
        AppColors.primary,
        AppColors.white,
        AppColors.ink,
      ),
      AnswerOptionState.correct => (
        AppColors.successSoft,
        AppColors.success,
        AppColors.success,
        AppColors.white,
        AppColors.ink,
      ),
      AnswerOptionState.incorrect => (
        AppColors.lightPink,
        AppColors.primary,
        AppColors.primary,
        AppColors.white,
        AppColors.ink,
      ),
      AnswerOptionState.disabled => (
        AppColors.white,
        AppColors.borderSoft,
        AppColors.creamSecondary,
        AppColors.gray,
        AppColors.inkSoft,
      ),
      AnswerOptionState.idle => (
        AppColors.white,
        AppColors.border,
        AppColors.creamSecondary,
        AppColors.inkSoft,
        AppColors.ink,
      ),
    };
    final trailing = switch (state) {
      AnswerOptionState.correct => Icons.check_circle_rounded,
      AnswerOptionState.incorrect => Icons.cancel_rounded,
      _ => null,
    };
    final duration = reduceMotionOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final radius = BorderRadius.circular(16);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: state == AnswerOptionState.selected ||
          state == AnswerOptionState.correct && onTap == null,
      child: Pressable(
        enabled: onTap != null,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: Border.all(
              color: border,
              width: state == AnswerOptionState.idle ||
                      state == AnswerOptionState.disabled
                  ? 1.2
                  : 2,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          index < _letters.length ? _letters[index] : '${index + 1}',
                          style: TextStyle(
                            color: badgeFg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailing, color: border, size: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
