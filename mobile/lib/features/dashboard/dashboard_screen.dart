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
import '../content/content_gateway.dart';
import '../content/local_vocabulary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.snapshot,
    required this.gateway,
    required this.onOpenModules,
    required this.onContinueLearning,
    required this.onOpenRewards,
    required this.onOpenVocabulary,
    super.key,
  });

  final LearningSnapshot snapshot;
  final AuthGateway gateway;
  final VoidCallback onOpenModules;
  final Future<void> Function(LearningModule module) onContinueLearning;
  final VoidCallback onOpenRewards;
  final VoidCallback onOpenVocabulary;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<LearningModule>> _modulesFuture;
  late Future<RewardsOverview> _rewardsFuture;
  Future<LocalVocabularyCatalog>? _vocabularyFuture;
  bool _isContinuingLearning = false;

  @override
  void initState() {
    super.initState();
    _modulesFuture = widget.gateway.fetchModules();
    _rewardsFuture = widget.gateway.fetchRewards();
    final gateway = widget.gateway;
    if (gateway is DictionaryGateway) {
      _vocabularyFuture = (gateway as DictionaryGateway).localVocabulary();
    }
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSnapshot = oldWidget.snapshot;
    final snapshot = widget.snapshot;
    if (snapshot.completedLessons != oldSnapshot.completedLessons ||
        snapshot.xp != oldSnapshot.xp ||
        snapshot.streak != oldSnapshot.streak ||
        snapshot.userLevel != oldSnapshot.userLevel) {
      _modulesFuture = widget.gateway.fetchModules();
      _rewardsFuture = widget.gateway.fetchRewards();
    }
  }

  Future<void> _continueLearning(LearningModule module) async {
    setState(() => _isContinuingLearning = true);
    try {
      await widget.onContinueLearning(module);
    } finally {
      if (mounted) setState(() => _isContinuingLearning = false);
    }
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
                  LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final continueLearning = _buildContinueLearning();
                      final dailyWord = _buildDailyWord();
                      if (contentConstraints.maxWidth >= 820) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: continueLearning),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: dailyWord),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          continueLearning,
                          const SizedBox(height: 24),
                          dailyWord,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _buildLearningModules(),
                  const SizedBox(height: 28),
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

  Widget _buildContinueLearning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Continue learning'),
        const SizedBox(height: 12),
        FutureBuilder<List<LearningModule>>(
          future: _modulesFuture,
          builder: (context, modulesSnapshot) {
            if (modulesSnapshot.connectionState == ConnectionState.waiting) {
              return const LearnLiteCard(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (modulesSnapshot.hasError) {
              return LearnLiteCard(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Learning content is unavailable',
                  message: 'Check your connection to load your modules.',
                  action: TextButton(
                    onPressed: () => setState(
                      () => _modulesFuture = widget.gateway.fetchModules(),
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
            currentModule ??= modules.isNotEmpty ? modules.first : null;
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
                      label: 'Browse lessons',
                      icon: Icons.grid_view_outlined,
                      onPressed: widget.onOpenModules,
                      variant: LearnLiteButtonVariant.outlined,
                    ),
                  ],
                ),
              );
            }

            final module = currentModule;
            final progress = module.lessonCount == 0
                ? 0.0
                : (module.completedLessons / module.lessonCount).clamp(
                    0.0,
                    1.0,
                  );
            final hasStarted =
                module.lastLessonIndex != null || module.completedLessons > 0;
            return LearnLiteCard(
              backgroundColor: AppColors.creamSecondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.lightPink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_stories_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          module.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      module.description,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.gray),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    '${module.completedLessons} of ${module.lessonCount} lessons',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  LearnLiteProgressIndicator(progress: progress),
                  const SizedBox(height: 16),
                  LearnLiteButton(
                    label: _isContinuingLearning
                        ? 'Opening lesson'
                        : hasStarted
                        ? 'Continue Learning'
                        : 'Start Learning',
                    icon: Icons.play_arrow_rounded,
                    isLoading: _isContinuingLearning,
                    onPressed: _isContinuingLearning
                        ? null
                        : () => _continueLearning(module),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDailyWord() {
    final vocabularyFuture = _vocabularyFuture;
    if (vocabularyFuture == null) {
      return const _DailyWordUnavailable();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Daily Word'),
        const SizedBox(height: 12),
        FutureBuilder<LocalVocabularyCatalog>(
          future: vocabularyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LearnLiteCard(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            if (snapshot.hasError) {
              return const _DailyWordUnavailable();
            }
            final words = snapshot.data!.vocabulary
                .where(
                  (entry) =>
                      entry.subanen.trim().isNotEmpty &&
                      entry.english.trim().isNotEmpty,
                )
                .toList();
            if (words.isEmpty) return const _DailyWordUnavailable();
            final today = DateTime.now();
            final dayOfYear = today.difference(DateTime(today.year)).inDays;
            final word = words[dayOfYear % words.length];
            return _DailyWordCard(
              word: word,
              onBrowse: widget.onOpenVocabulary,
            );
          },
        ),
      ],
    );
  }

  Widget _buildLearningModules() {
    return FutureBuilder<List<LearningModule>>(
      future: _modulesFuture,
      builder: (context, snapshot) {
        final modules = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Learning modules',
              trailing: TextButton(
                onPressed: widget.onOpenModules,
                child: const Text('Explore all'),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LearnLiteCard(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (snapshot.hasError)
              const _FeatureEmptyCard(
                icon: Icons.cloud_off_outlined,
                message: 'Modules are unavailable right now.',
              )
            else if (modules.isEmpty)
              const _FeatureEmptyCard(
                icon: Icons.auto_stories_outlined,
                message: 'Approved learning modules will appear here.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 580
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final module in modules.take(6))
                        SizedBox(
                          width: width,
                          child: _ModuleCategoryCard(
                            module: module,
                            onTap: widget.onOpenModules,
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.redDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WELCOME BACK',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.gold,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready for today’s lesson?',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: AppColors.white, fontSize: 26),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Build your Subanen language and culture skills, one step at a time.',
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
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      LearnerAvatar(
                        imageUrl: snapshot.avatarUrl,
                        size: 68,
                        backgroundColor: AppColors.lightPink,
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ],
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

class _ModuleCategoryCard extends StatelessWidget {
  const _ModuleCategoryCard({required this.module, required this.onTap});

  final LearningModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = module.lessonCount == 0
        ? 0.0
        : (module.completedLessons / module.lessonCount).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: LearnLiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.category_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.gray),
                ],
              ),
              if (module.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  module.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.gray),
                ),
              ],
              const SizedBox(height: 14),
              LearnLiteProgressIndicator(progress: progress),
              const SizedBox(height: 6),
              Text(
                '${module.completedLessons}/${module.lessonCount} lessons',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.gray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyWordCard extends StatelessWidget {
  const _DailyWordCard({required this.word, required this.onBrowse});

  final LocalVocabularyEntry word;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    backgroundColor: AppColors.creamSecondary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Today’s word',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          word.subanen,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _TranslationLine(label: 'English', value: word.english),
        if (word.bisaya.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _TranslationLine(label: 'Bisaya/Cebuano', value: word.bisaya),
        ],
        const SizedBox(height: 8),
        const _TranslationLine(
          label: 'Filipino',
          value: 'Translation not yet available in the vocabulary data.',
        ),
        if (word.topic.isNotEmpty || word.module.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            [
              word.module,
              word.topic,
            ].where((value) => value.trim().isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.gray),
          ),
        ],
        if (word.reviewStatus.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.fact_check_outlined, size: 16),
            label: Text(word.reviewStatus),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onBrowse,
            child: const Text('Browse vocabulary'),
          ),
        ),
      ],
    ),
  );
}

class _TranslationLine extends StatelessWidget {
  const _TranslationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 112,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.gray),
        ),
      ),
      Expanded(child: Text(value)),
    ],
  );
}

class _DailyWordUnavailable extends StatelessWidget {
  const _DailyWordUnavailable();

  @override
  Widget build(BuildContext context) => const LearnLiteCard(
    child: EmptyState(
      icon: Icons.menu_book_outlined,
      title: 'Daily Word unavailable',
      message: 'A complete Subanen and English word pair is not available.',
    ),
  );
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
