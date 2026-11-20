import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_theme.dart';
import '../../app/responsive_layout.dart';
import '../../core/learning_snapshot.dart';
import 'daily_engagement_card.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learner_avatar.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pressable.dart';
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

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EntranceFade(
                    child: _WelcomeCard(snapshot: widget.snapshot),
                  ),
                  const SizedBox(height: 26),
                  EntranceFade(
                    delayIndex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Your learning snapshot'),
                        const SizedBox(height: 12),
                        _SnapshotStrip(snapshot: widget.snapshot),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  EntranceFade(
                    delayIndex: 2,
                    child: LayoutBuilder(
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
                            const SizedBox(height: 26),
                            dailyWord,
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  EntranceFade(
                    delayIndex: 3,
                    child: DailyEngagementCard(
                      rewardsFuture: _rewardsFuture,
                      onRetry: () {
                        setState(() {
                          _rewardsFuture = widget.gateway.fetchRewards();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  _buildLearningModules(),
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Latest badges',
                    trailing: TextButton(
                      onPressed: widget.onOpenRewards,
                      child: const Text('See all'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<RewardsOverview>(
                    future: _rewardsFuture,
                    builder: (context, rewardsSnapshot) {
                      if (rewardsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const LoadingCard(height: 88);
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < earnedBadges.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const IconBadge(
                                      icon: Icons.workspace_premium_rounded,
                                      tone: IconBadgeTone.gold,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            earnedBadges[index].title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            earnedBadges[index].description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.inkSoft,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
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
              return const LoadingCard(height: 190);
            }
            if (modulesSnapshot.hasError) {
              return LearnLiteCard(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Learning content is unavailable',
                  message: 'Check your connection to load your modules.',
                  action: TextButton(
                    onPressed: () => setState(() {
                      _modulesFuture = widget.gateway.fetchModules();
                    }),
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
                    const IconBadge(icon: Icons.auto_stories_rounded),
                    const SizedBox(height: 12),
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
                          ?.copyWith(color: AppColors.inkSoft),
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
            final textTheme = Theme.of(context).textTheme;
            return LearnLiteCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(
                        icon: Icons.auto_stories_rounded,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusPill(
                              label: hasStarted ? 'In progress' : 'Up next',
                              tone: hasStarted
                                  ? IconBadgeTone.red
                                  : IconBadgeTone.gold,
                            ),
                            const SizedBox(height: 6),
                            Text(module.title, style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      module.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${module.completedLessons} of ${module.lessonCount} lessons',
                          style: textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LearnLiteProgressIndicator(progress: progress),
                  const SizedBox(height: 18),
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
              return const LoadingCard(height: 200);
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
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LoadingCard(height: 96)
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

/// Nickname, then full name, then "learner"; blank values are skipped so the
/// greeting never reads "Welcome, ".
String _displayName(LearningSnapshot snapshot) => [
  snapshot.nickname,
  snapshot.fullName,
].map((value) => value?.trim() ?? '').firstWhere(
  (value) => value.isNotEmpty,
  orElse: () => 'learner',
);

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.snapshot});

  final LearningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final levelXp = snapshot.xp.remainder(100);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.redDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // A large faint diamond: the woven motif as a watermark.
              Positioned(
                right: -64,
                top: -56,
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.13),
                          width: 14,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LearnerAvatar(
                              imageUrl: snapshot.avatarUrl,
                              avatarId: snapshot.avatarId,
                              size: 56,
                              backgroundColor: AppColors.lightPink,
                              borderColor: AppColors.gold,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WELCOME BACK',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.gold,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Welcome, ${_displayName(snapshot)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleLarge?.copyWith(
                                      color: AppColors.white,
                                      fontSize: 21,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Ready for today’s lesson?',
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Build your Subanen language and culture skills, one step at a time.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.86),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Level ${snapshot.userLevel}',
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$levelXp / 100 XP',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LearnLiteProgressIndicator(
                          progress: levelXp / 100,
                          color: AppColors.gold,
                          backgroundColor: AppColors.darkBackground.withValues(
                            alpha: 0.28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DecorativeBorder(color: AppColors.gold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four compact statistics in one card: value first, label underneath.
class _SnapshotStrip extends StatelessWidget {
  const _SnapshotStrip({required this.snapshot});

  final LearningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.auto_stories_rounded, '${snapshot.completedLessons}', 'Lessons done'),
      (Icons.bolt_rounded, '${snapshot.xp}', 'XP'),
      (
        Icons.local_fire_department_rounded,
        '${snapshot.streak}',
        'Day streak',
      ),
      (Icons.stars_rounded, '${snapshot.userLevel}', 'Level'),
    ];
    return LearnLiteCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0)
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
              Expanded(
                child: _SnapshotStat(
                  icon: items[index].$1,
                  value: items[index].$2,
                  label: items[index].$3,
                  tone: index.isEven ? IconBadgeTone.red : IconBadgeTone.gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnapshotStat extends StatelessWidget {
  const _SnapshotStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String value;
  final String label;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, tone: tone, size: 34),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const IconBadge(icon: Icons.category_rounded, tone: IconBadgeTone.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: textTheme.titleSmall),
                if (module.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    module.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                LearnLiteProgressIndicator(progress: progress, minHeight: 6),
                const SizedBox(height: 5),
                Text(
                  '${module.completedLessons}/${module.lessonCount} lessons',
                  style: textTheme.labelSmall?.copyWith(color: AppColors.gray),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _DailyWordCard extends StatelessWidget {
  const _DailyWordCard({required this.word, required this.onBrowse});

  final LocalVocabularyEntry word;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      backgroundColor: AppColors.charcoal,
      padding: EdgeInsets.zero,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Today’s word',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  word.subanen,
                  style: textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 14),
                _TranslationLine(label: 'English', value: word.english),
                if (word.bisaya.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _TranslationLine(label: 'Bisaya/Cebuano', value: word.bisaya),
                ],
                const SizedBox(height: 8),
                const _TranslationLine(
                  label: 'Filipino',
                  value: 'Translation not yet available in the vocabulary data.',
                  muted: true,
                ),
                if (word.topic.isNotEmpty ||
                    word.module.isNotEmpty ||
                    word.reviewStatus.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (word.topic.isNotEmpty || word.module.isNotEmpty)
                        _DarkTag(
                          icon: Icons.label_outline_rounded,
                          label: [word.module, word.topic]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' · '),
                        ),
                      if (word.reviewStatus.trim().isNotEmpty)
                        _DarkTag(
                          icon: Icons.fact_check_outlined,
                          label: word.reviewStatus,
                        ),
                    ],
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onBrowse,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Browse vocabulary'),
                  ),
                ),
              ],
            ),
          ),
          const DecorativeBorder(height: 8),
        ],
      ),
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TranslationLine extends StatelessWidget {
  const _TranslationLine({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 112,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: muted ? 0.55 : 0.95),
            fontSize: muted ? 13 : 15,
            fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            fontStyle: muted ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
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
        IconBadge(icon: icon, tone: IconBadgeTone.cream, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ],
    ),
  );
}
