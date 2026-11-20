import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../core/display_format.dart';
import '../../core/learning_snapshot.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';
import 'daily_engagement_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.snapshot,
    required this.gateway,
    required this.onOpenRewards,
    super.key,
  });

  final LearningSnapshot snapshot;
  final AuthGateway gateway;
  final VoidCallback onOpenRewards;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<List<LearningModule>> _modulesFuture;
  late Future<RewardsOverview> _rewardsFuture;
  late Future<List<_QuizHistoryEntry>> _quizHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.completedLessons !=
            oldWidget.snapshot.completedLessons ||
        widget.snapshot.xp != oldWidget.snapshot.xp ||
        widget.snapshot.streak != oldWidget.snapshot.streak) {
      _loadProgress();
    }
  }

  void _loadProgress() {
    _modulesFuture = widget.gateway.fetchModules();
    _rewardsFuture = widget.gateway.fetchRewards();
    _quizHistoryFuture = _loadQuizHistory();
  }

  Future<List<_QuizHistoryEntry>> _loadQuizHistory() async {
    final modules = await widget.gateway.fetchModules();
    final history = <_QuizHistoryEntry>[];
    for (final module in modules) {
      for (final lesson in module.lessons.where(
        (lesson) => lesson.quiz.isNotEmpty,
      )) {
        final attempts = await widget.gateway.fetchLessonQuizAttempts(
          module.id,
          lesson.index,
        );
        history.addAll(
          attempts.map(
            (attempt) => _QuizHistoryEntry(
              title: '${module.title} · ${lesson.title}',
              score: attempt.score,
              correctAnswers: attempt.correctAnswers,
              totalQuestions: attempt.totalQuestions,
              completedAt: attempt.completedAt,
              answerDetails: [
                for (final question in attempt.questions)
                  '${question.question}\n'
                      'Your answer: '
                      '${question.choices[question.selectedAnswerIndex]}'
                      '${question.selectedAnswerIndex == question.correctAnswerIndex ? '' : '\nCorrect answer: ${question.choices[question.correctAnswerIndex]}'}',
              ],
            ),
          ),
        );
      }
    }
    if (widget.gateway case final DictionaryGateway dictionaryGateway) {
      final attempts = await dictionaryGateway.fetchVocabularyQuizAttempts();
      history.addAll(
        attempts.map(
          (attempt) => _QuizHistoryEntry(
            title: 'Vocabulary · ${attempt.category}',
            score: attempt.score,
            correctAnswers: attempt.correctAnswers,
            totalQuestions: attempt.totalQuestions,
            completedAt: attempt.completedAt,
            answerDetails: [
              for (final response in attempt.responses)
                '${response.english}\n'
                    'Your answer: ${response.selectedAnswer}'
                    '${response.isCorrect ? '' : '\nCorrect answer: ${response.correctAnswer}'}',
            ],
          ),
        ),
      );
    }
    history.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return history;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ResponsiveLayout.horizontalPadding(
          constraints.maxWidth,
        );
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final contentWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, ResponsiveLayout.contentMaxWidth);
        final metricWidth = (contentWidth - 12 * (columns - 1)) / columns;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ResponsiveLayout.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Your learning progress',
                      subtitle: 'Every lesson builds a stronger foundation.',
                    ),
                    const SizedBox(height: 14),
                    EntranceFade(
                      child: _LevelHeroCard(snapshot: widget.snapshot),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ProgressMetric(
                          width: metricWidth,
                          icon: Icons.auto_stories_rounded,
                          label: 'Lessons completed',
                          value: '${widget.snapshot.completedLessons}',
                          tone: IconBadgeTone.red,
                        ),
                        _ProgressMetric(
                          width: metricWidth,
                          icon: Icons.bolt_rounded,
                          label: 'Experience points',
                          value: '${widget.snapshot.xp}',
                          tone: IconBadgeTone.gold,
                        ),
                        _ProgressMetric(
                          width: metricWidth,
                          icon: Icons.local_fire_department_rounded,
                          label: 'Current streak',
                          value: dayCount(widget.snapshot.streak),
                          tone: IconBadgeTone.red,
                        ),
                        _ProgressMetric(
                          width: metricWidth,
                          icon: Icons.stars_rounded,
                          label: 'Level',
                          value: '${widget.snapshot.userLevel}',
                          tone: IconBadgeTone.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DailyEngagementCard(
                      rewardsFuture: _rewardsFuture,
                      onRetry: () => setState(_loadProgress),
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: 'Progress by module',
                      trailing: TextButton(
                        onPressed: widget.onOpenRewards,
                        child: const Text('Badges & certificates'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<LearningModule>>(
                      future: _modulesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LoadingCard(height: 110);
                        }
                        if (snapshot.hasError) {
                          return LearnLiteCard(
                            child: EmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: 'Module progress is unavailable',
                              message: 'Check your connection and try again.',
                              action: TextButton(
                                onPressed: () => setState(() {
                                  _modulesFuture = widget.gateway
                                      .fetchModules();
                                }),
                                child: const Text('Try again'),
                              ),
                            ),
                          );
                        }
                        final modules = snapshot.data ?? const [];
                        if (modules.isEmpty) {
                          return const LearnLiteCard(
                            child: EmptyState(
                              icon: Icons.auto_stories_outlined,
                              title: 'No module progress yet',
                              message: 'Start a lesson to see progress by learning category.',
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final module in modules) ...[
                              _ModuleProgressCard(module: module),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Quiz history'),
                    const SizedBox(height: 12),
                    FutureBuilder<List<_QuizHistoryEntry>>(
                      future: _quizHistoryFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LoadingCard(height: 110);
                        }
                        if (snapshot.hasError) {
                          return LearnLiteCard(
                            child: EmptyState(
                              icon: Icons.history_outlined,
                              title: 'Quiz history is unavailable',
                              message: '${snapshot.error}',
                              action: TextButton(
                                onPressed: () => setState(() {
                                  _quizHistoryFuture = _loadQuizHistory();
                                }),
                                child: const Text('Try again'),
                              ),
                            ),
                          );
                        }
                        final attempts = snapshot.data ?? const [];
                        if (attempts.isEmpty) {
                          return const LearnLiteCard(
                            child: EmptyState(
                              icon: Icons.history_outlined,
                              title: 'No quiz results yet',
                              message: 'Completed lesson and vocabulary quizzes will appear here.',
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final attempt in attempts) ...[
                              LearnLiteCard(
                                padding: EdgeInsets.zero,
                                child: Material(
                                  color: AppColors.white,
                                  child: ExpansionTile(
                                    leading: _ScoreBadge(score: attempt.score),
                                    title: Text(attempt.title),
                                    subtitle: Text(
                                      '${attempt.score}% · '
                                      '${attempt.correctAnswers} of '
                                      '${attempt.totalQuestions} correct · '
                                      '${friendlyDateTime(attempt.completedAt)}',
                                    ),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    children: [
                                      for (final detail
                                          in attempt.answerDetails)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(detail),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuizHistoryEntry {
  const _QuizHistoryEntry({
    required this.title,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.completedAt,
    required this.answerDetails,
  });

  final String title;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final DateTime completedAt;
  final List<String> answerDetails;
}

/// "1 day", "2 days": correct singular/plural for day counts.
String dayCount(int days) => '$days ${days == 1 ? 'day' : 'days'}';

/// Dark level card: a ring showing XP toward the next level.
class _LevelHeroCard extends StatelessWidget {
  const _LevelHeroCard({required this.snapshot});

  final LearningSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final levelXp = snapshot.xp.remainder(100);
    return LearnLiteCard(
      backgroundColor: AppColors.charcoal,
      padding: EdgeInsets.zero,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ScoreRing(
                  progress: levelXp / 100,
                  size: 96,
                  color: AppColors.gold,
                  trackColor: AppColors.white.withValues(alpha: 0.1),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LEVEL',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.6),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${snapshot.userLevel}',
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$levelXp / 100 XP',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'toward Level ${snapshot.userLevel + 1}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatusPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '${dayCount(snapshot.streak)} streak',
                        tone: IconBadgeTone.dark,
                      ),
                    ],
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final good = score >= 80;
    final ok = score >= 50;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: good
            ? AppColors.successSoft
            : ok
            ? AppColors.goldSoft
            : AppColors.lightPink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: good
              ? AppColors.success
              : ok
              ? AppColors.goldDeep
              : AppColors.primary,
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: LearnLiteCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(icon: icon, tone: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ModuleProgressCard extends StatelessWidget {
  const _ModuleProgressCard({required this.module});

  final LearningModule module;

  @override
  Widget build(BuildContext context) {
    final progress = module.lessonCount == 0
        ? 0.0
        : (module.completedLessons / module.lessonCount).clamp(0.0, 1.0);
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: progress >= 1
                ? Icons.emoji_events_rounded
                : Icons.auto_stories_rounded,
            tone: progress >= 1 ? IconBadgeTone.dark : IconBadgeTone.red,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(module.title, style: textTheme.titleSmall),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (module.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    module.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LearnLiteProgressIndicator(progress: progress),
                const SizedBox(height: 6),
                Text(
                  '${module.completedLessons} of ${module.lessonCount} lessons completed',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
