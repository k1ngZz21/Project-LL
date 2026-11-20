import 'package:flutter/material.dart';

import '../app/app_colors.dart';

/// A section title with a small woven-diamond accent, an optional subtitle
/// and an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.showAccent = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showAccent) ...[
          const _DiamondAccent(),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A red diamond with a gold centre, echoing the woven border motif.
class _DiamondAccent extends StatelessWidget {
  const _DiamondAccent();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 11,
        height: 11,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Container(
          width: 4,
          height: 4,
          color: AppColors.gold,
        ),
      ),
    ),
  );
}
