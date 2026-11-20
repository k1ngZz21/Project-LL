import 'package:flutter/material.dart';

import '../app/app_colors.dart';

enum IconBadgeTone { red, gold, dark, cream }

/// A rounded-square tile holding an icon (or short text such as a number).
/// The single way LearnLite shows leading icons on cards and rows.
class IconBadge extends StatelessWidget {
  const IconBadge({
    this.icon,
    this.text,
    this.tone = IconBadgeTone.red,
    this.size = 44,
    super.key,
  }) : assert(icon != null || text != null);

  final IconData? icon;
  final String? text;
  final IconBadgeTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      IconBadgeTone.red => (AppColors.lightPink, AppColors.primary),
      IconBadgeTone.gold => (AppColors.goldSoft, AppColors.goldDeep),
      IconBadgeTone.dark => (AppColors.darkBackground, AppColors.gold),
      IconBadgeTone.cream => (AppColors.creamSecondary, AppColors.inkSoft),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: icon != null
          ? Icon(icon, color: foreground, size: size * 0.5)
          : Text(
              text!,
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// A small rounded label for statuses such as "In progress" or "+10 XP".
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    this.icon,
    this.tone = IconBadgeTone.cream,
    super.key,
  });

  final String label;
  final IconData? icon;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      IconBadgeTone.red => (AppColors.lightPink, AppColors.redDark),
      IconBadgeTone.gold => (AppColors.goldSoft, AppColors.goldDeep),
      IconBadgeTone.dark => (AppColors.darkBackground, AppColors.gold),
      IconBadgeTone.cream => (AppColors.creamSecondary, AppColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
