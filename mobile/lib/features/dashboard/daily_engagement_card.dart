import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';

class DailyEngagementCard extends StatelessWidget {
  const DailyEngagementCard({
    required this.rewardsFuture,
    required this.onRetry,
    super.key,
  });

  final Future<RewardsOverview> rewardsFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RewardsOverview>(
      future: rewardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard(height: 168);
        }
        if (snapshot.hasError) {
          return LearnLiteCard(
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Daily activity is unavailable',
              message: 'Check your connection to load quests and streaks.',
              action: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          );
        }
        final overview = snapshot.data!;
        final textTheme = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LearnLiteCard(
              backgroundColor: AppColors.charcoal,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(
                        icon: Icons.local_fire_department_rounded,
                        tone: IconBadgeTone.dark,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Learning streak',
                              style: textTheme.titleMedium?.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              'Best streak: ${overview.longestStreak} '
                              '${overview.longestStreak == 1 ? 'day' : 'days'}',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${overview.streak} ${overview.streak == 1 ? 'day' : 'days'}',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final day in overview.calendar)
                        _CalendarDay(day: day),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Daily Quests'),
            const SizedBox(height: 12),
            _QuestRow(
              icon: Icons.task_alt_rounded,
              tone: IconBadgeTone.red,
              title: overview.dailyQuest.title,
              description: overview.dailyQuest.description,
              reward: overview.dailyQuest.completed
                  ? '+${overview.dailyQuest.xpAwarded} XP earned'
                  : '${overview.dailyQuest.xpReward} XP',
              done: overview.dailyQuest.completed,
              progress: overview.dailyQuest.target == 0
                  ? 0
                  : overview.dailyQuest.progress / overview.dailyQuest.target,
              progressLabel:
                  '${overview.dailyQuest.progress} of '
                  '${overview.dailyQuest.target} lessons',
            ),
            const SizedBox(height: 12),
            _QuestRow(
              icon: overview.weeklyChest.unlocked
                  ? Icons.inventory_2
                  : Icons.inventory_2_outlined,
              tone: IconBadgeTone.gold,
              title: overview.weeklyChest.title,
              description: overview.weeklyChest.unlocked
                  ? 'Weekly reward unlocked.'
                  : overview.weeklyChest.description,
              reward: overview.weeklyChest.unlocked
                  ? '+${overview.weeklyChest.xpAwarded} XP earned'
                  : '${overview.weeklyChest.xpReward} XP',
              done: overview.weeklyChest.unlocked,
              progress: overview.weeklyChest.target == 0
                  ? 0
                  : overview.weeklyChest.progress / overview.weeklyChest.target,
              progressLabel:
                  '${overview.weeklyChest.progress} of '
                  '${overview.weeklyChest.target} lessons this week',
            ),
          ],
        );
      },
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.description,
    required this.reward,
    required this.done,
    required this.progress,
    required this.progressLabel,
  });

  final IconData icon;
  final IconBadgeTone tone;
  final String title;
  final String description;
  final String reward;
  final bool done;
  final double progress;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title, style: textTheme.titleSmall)),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: reward,
                      icon: done ? Icons.check_rounded : Icons.bolt_rounded,
                      tone: done ? IconBadgeTone.red : IconBadgeTone.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                LearnLiteProgressIndicator(
                  progress: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                ),
                const SizedBox(height: 5),
                Text(
                  progressLabel,
                  style: textTheme.labelSmall?.copyWith(color: AppColors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.day});

  final RewardCalendarDay day;

  @override
  Widget build(BuildContext context) {
    final background = day.active
        ? AppColors.primary
        : day.isToday
        ? AppColors.white.withValues(alpha: 0.08)
        : Colors.transparent;
    final foreground = day.active
        ? AppColors.white
        : day.isFuture
        ? AppColors.white.withValues(alpha: 0.35)
        : AppColors.white.withValues(alpha: 0.7);
    final dateText = day.date.day.toString();
    return Semantics(
      label:
          '${day.weekday} $dateText${day.active ? ', learning activity recorded' : ''}',
      child: Column(
        children: [
          Text(
            day.weekday.length > 3 ? day.weekday.substring(0, 3) : day.weekday,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: day.isToday
                  ? Border.all(color: AppColors.gold, width: 1.5)
                  : null,
            ),
            child: day.active
                ? const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: AppColors.gold,
                  )
                : Text(
                    dateText,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: day.isToday
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
