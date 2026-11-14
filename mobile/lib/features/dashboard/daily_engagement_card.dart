import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
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
          return const LearnLiteCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LearnLiteCard(
              backgroundColor: AppColors.lightPink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_outlined,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Learning streak',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${overview.streak} ${overview.streak == 1 ? 'day' : 'days'}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final day in overview.calendar)
                        _CalendarDay(day: day),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Best streak: ${overview.longestStreak} '
                    '${overview.longestStreak == 1 ? 'day' : 'days'}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.gray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Daily Quests', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            LearnLiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.task_alt, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overview.dailyQuest.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        overview.dailyQuest.completed
                            ? '+${overview.dailyQuest.xpAwarded} XP earned'
                            : '${overview.dailyQuest.xpReward} XP',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overview.dailyQuest.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.gray),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value:
                        overview.dailyQuest.progress /
                        overview.dailyQuest.target,
                    color: AppColors.primary,
                    backgroundColor: AppColors.lightPink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${overview.dailyQuest.progress} of '
                    '${overview.dailyQuest.target} lessons',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.gray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LearnLiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        overview.weeklyChest.unlocked
                            ? Icons.inventory_2
                            : Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overview.weeklyChest.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        overview.weeklyChest.unlocked
                            ? '+${overview.weeklyChest.xpAwarded} XP earned'
                            : '${overview.weeklyChest.xpReward} XP',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overview.weeklyChest.unlocked
                        ? 'Weekly reward unlocked.'
                        : overview.weeklyChest.description,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.gray),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value:
                        overview.weeklyChest.progress /
                        overview.weeklyChest.target,
                    color: AppColors.primary,
                    backgroundColor: AppColors.lightPink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${overview.weeklyChest.progress} of '
                    '${overview.weeklyChest.target} lessons this week',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppColors.gray),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
        ? AppColors.white
        : Colors.transparent;
    final foreground = day.active
        ? AppColors.white
        : day.isFuture
        ? AppColors.gray.withValues(alpha: 0.6)
        : AppColors.gray;
    final dateText = day.date.day.toString();
    return Semantics(
      label:
          '${day.weekday} $dateText${day.active ? ', learning activity recorded' : ''}',
      child: Column(
        children: [
          Text(
            day.weekday,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: 5),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: day.isToday ? Border.all(color: AppColors.primary) : null,
            ),
            child: Text(
              dateText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: day.isToday ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
