import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../core/learning_snapshot.dart';
import 'daily_engagement_card.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learner_avatar.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.snapshot,
    required this.gateway,
    required this.onOpenModules,
    required this.onContinueLearning,
    required this.onOpenRewards,
    super.key,
  });

  final LearningSnapshot snapshot;
  final AuthGateway gateway;
  final VoidCallback onOpenModules;
  final VoidCallback onContinueLearning;
  final VoidCallback onOpenRewards;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<LearningModule>> _modulesFuture;
  late Future<RewardsOverview> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _modulesFuture = widget.gateway.fetchModules();
    _rewardsFuture = widget.gateway.fetchRewards();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final contentWidth = availableWidth.clamp(
          0.0,
          ResponsiveLayout.contentMaxWidth,
        );
        final horizontalPadding = ResponsiveLayout.horizontalPadding(
          contentWidth,
        );
        final columns = contentWidth >= 920 ? 4 : 2;
        final metricWidth =
            (contentWidth - (horizontalPadding * 2) - (16 * (columns - 1))) /
            columns;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WelcomeCard(snapshot: widget.snapshot),
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'Your learning snapshot'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricCard(
                        width: metricWidth,
                        icon: Icons.auto_stories_outlined,
                        label: 'Lessons completed',
                        value: '${widget.snapshot.completedLessons}',
                      ),
                      _MetricCard(
                        width: metricWidth,
                        icon: Icons.bolt_outlined,
                        label: 'Experience points',
                        value: '${widget.snapshot.xp}',
                      ),
                      _MetricCard(
                        width: metricWidth,
                        icon: Icons.local_fire_department_outlined,
                        label: 'Learning streak',
                        value: '${widget.snapshot.streak}',
                      ),
                      _MetricCard(
                        width: metricWidth,
                        icon: Icons.stars_outlined,
                        label: 'Level',
                        value: '${widget.snapshot.userLevel}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  DailyEngagementCard(
                    rewardsFuture: _rewardsFuture,
                    onRetry: () {
                      setState(
                        () => _rewardsFuture = widget.gateway.fetchRewards(),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'Continue Learning'),
                  const SizedBox(height: 14),
                  FutureBuilder<List<LearningModule>>(
                    future: _modulesFuture,
                    builder: (context, modulesSnapshot) {
                      if (modulesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LearnLiteCard(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }
                      if (modulesSnapshot.hasError) {
                        return LearnLiteCard(
                          child: EmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Learning content is unavailable',
                            message:
                                'Check your connection to load your modules.',
                            action: TextButton(
                              onPressed: () => setState(
                                () => _modulesFuture = widget.gateway
                                    .fetchModules(),
                              ),
                              child: const Text('Try again'),
                            ),
                          ),
                        );
                      }
                      final modules = modulesSnapshot.data ?? const [];
                      LearningModule? currentModule;
                      for (final module in modules) {
                        if (module.completedLessons < module.lessonCount) {
                          currentModule = module;
                          break;
                        }
                      }
                      if (currentModule == null && modules.isNotEmpty) {
                        currentModule = modules.first;
                      }
                      if (currentModule == null) {
                        return LearnLiteCard(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.auto_stories_outlined,
                                size: 32,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No learning modules are available yet.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Approved modules will appear here when content is uploaded.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.gray),
                              ),
                              const SizedBox(height: 16),
                              LearnLiteButton(
                                label: 'Browse modules',
                                icon: Icons.grid_view_outlined,
                                onPressed: widget.onOpenModules,
                                variant: LearnLiteButtonVariant.outlined,
                              ),
                            ],
                          ),
                        );
                      }
                      return LearnLiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentModule.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${currentModule.completedLessons} of ${currentModule.lessonCount} lessons completed',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.gray),
                            ),
                            const SizedBox(height: 14),
                            LearnLiteProgressIndicator(
                              progress: currentModule.lessonCount == 0
                                  ? 0
                                  : currentModule.completedLessons /
                                        currentModule.lessonCount,
                            ),
                            const SizedBox(height: 16),
                            LearnLiteButton(
                              label: currentModule.lastLessonIndex == null
                                  ? 'Start Learning'
                                  : 'Continue Learning',
                              onPressed: widget.onContinueLearning,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SectionHeader(
                    title: 'Latest badges',
                    trailing: TextButton(
                      onPressed: widget.onOpenRewards,
                      child: const Text('See all'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<RewardsOverview>(
                    future: _rewardsFuture,
                    builder: (context, rewardsSnapshot) {
                      if (rewardsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LearnLiteCard(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }
                      if (rewardsSnapshot.hasError) {
                        return const _FeatureEmptyCard(
                          icon: Icons.cloud_off_outlined,
                          message: 'Latest badges are unavailable right now.',
                        );
                      }

                      final earnedBadges = rewardsSnapshot.data!.badges
                          .where((badge) => badge.earned)
                          .take(3)
                          .toList();
                      if (earnedBadges.isEmpty) {
                        return const _FeatureEmptyCard(
                          icon: Icons.workspace_premium_outlined,
                          message: 'Earned badges will appear here.',
                        );
                      }

                      return LearnLiteCard(
                        child: Column(
                          children: [
                            for (final badge in earnedBadges)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.workspace_premium_outlined,
                                  color: AppColors.gold,
                                ),
                                title: Text(badge.title),
                                subtitle: Text(badge.description),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.snapshot});

  final LearningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.primary),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your learning journey',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Subanen Language & Culture',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome, ${snapshot.nickname ?? snapshot.fullName ?? 'learner'}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  LearnerAvatar(
                    imageUrl: snapshot.avatarUrl,
                    size: 68,
                    backgroundColor: AppColors.lightPink,
                  ),
                ],
              ),
            ),
            const DecorativeBorder(color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

class _FeatureEmptyCard extends StatelessWidget {
  const _FeatureEmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(icon, color: AppColors.gray),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.gray),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: LearnLiteCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.gray),
            ),
          ],
        ),
      ),
    );
  }
}
