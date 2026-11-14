import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({
    this.imageUrl,
    this.size = 48,
    this.backgroundColor = AppColors.lightPink,
    this.borderColor = AppColors.white,
    super.key,
  });

  final String? imageUrl;
  final double size;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Semantics(
      label: hasImage ? 'Learner avatar' : 'No learner avatar set',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: ClipOval(
          child: ColoredBox(
            color: backgroundColor,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.person_outline, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
