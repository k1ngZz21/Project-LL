import 'package:flutter/material.dart';

import '../app/app_colors.dart';
import '../core/avatar_design.dart';
import 'subanen_avatar.dart';

class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({
    this.imageUrl,
    this.avatarId,
    this.design,
    this.size = 48,
    this.backgroundColor = AppColors.lightPink,
    this.borderColor = AppColors.white,
    super.key,
  });

  final String? imageUrl;

  /// A stored LearnLite avatar (`learners.avatar_id`); drawn when valid.
  final String? avatarId;

  /// An unsaved design, e.g. the live preview while editing.
  final AvatarDesign? design;
  final double size;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final drawn = design ?? AvatarDesign.tryParse(avatarId);
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final Widget content;
    if (drawn != null) {
      content = SubanenAvatar(design: drawn, size: size);
    } else if (hasImage) {
      content = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person_outline, color: AppColors.primary),
      );
    } else {
      content = const Icon(Icons.person_outline, color: AppColors.primary);
    }
    final avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: drawn?.backgroundColor ?? backgroundColor,
          child: content,
        ),
      ),
    );
    if (drawn != null) return avatar; // SubanenAvatar has its own label.
    return Semantics(
      label: hasImage ? 'Learner avatar' : 'No learner avatar set',
      image: true,
      child: avatar,
    );
  }
}
