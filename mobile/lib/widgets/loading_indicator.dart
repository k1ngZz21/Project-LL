import 'package:flutter/material.dart';

import '../app/app_colors.dart';

class LearnLiteLoadingIndicator extends StatelessWidget {
  const LearnLiteLoadingIndicator({this.label = 'Loading', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: 'In progress',
      child: const Center(
        child: SizedBox.square(
          dimension: 30,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
            strokeCap: StrokeCap.round,
          ),
        ),
      ),
    );
  }
}

/// A calm placeholder card shown while a section loads, sized like content
/// so the layout does not jump when data arrives.
class LoadingCard extends StatelessWidget {
  const LoadingCard({this.height = 120, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderSoft),
    ),
    child: const LearnLiteLoadingIndicator(),
  );
}
