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
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
