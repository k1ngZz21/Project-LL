import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../core/avatar_design.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learner_avatar.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';
import '../content/offline_content_screen.dart';
import '../settings/settings_screen.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({
    required this.profile,
    required this.gateway,
    this.onEditNickname,
    this.onOpenRewards,
    this.onSignOut,
    super.key,
  });

  final LearnerProfile profile;
  final AuthGateway gateway;
  final VoidCallback? onEditNickname;
  final VoidCallback? onOpenRewards;
  final Future<void> Function()? onSignOut;

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  late Future<RewardsOverview> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = widget.gateway.fetchRewards();
  }

  @override
  void didUpdateWidget(covariant AvatarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gateway != oldWidget.gateway) {
      _rewardsFuture = widget.gateway.fetchRewards();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ResponsiveLayout.horizontalPadding(
          constraints.maxWidth,
        );
        final levelProgress = widget.profile.xp.remainder(100) / 100;
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
                    const SectionHeader(title: 'My Avatar'),
                    const SizedBox(height: 14),
                    EntranceFade(
                      child: _ProfileHero(
                        profile: widget.profile,
                        levelProgress: levelProgress,
                      ),
                    ),
                    const SizedBox(height: 16),
                    EntranceFade(
                      delayIndex: 1,
                      child: _AvatarStats(
                        profile: widget.profile,
                        rewardsFuture: _rewardsFuture,
                      ),
                    ),
                    if (widget.onOpenRewards != null) ...[
                      const SizedBox(height: 12),
                      LearnLiteCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _ProfileMenuRow(
                          icon: Icons.workspace_premium_rounded,
                          tone: IconBadgeTone.gold,
                          label: 'Badges & certificates',
                          onTap: widget.onOpenRewards!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    const SectionHeader(title: 'Customization'),
                    const SizedBox(height: 12),
                    _CustomizeAvatarCard(
                      avatarId: widget.profile.avatarId,
                      onCustomize: widget.onEditNickname,
                    ),
                    const SizedBox(height: 26),
                    const SectionHeader(title: 'Account'),
                    const SizedBox(height: 12),
                    LearnLiteCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          if (widget.onEditNickname != null)
                            _ProfileMenuRow(
                              icon: Icons.edit_rounded,
                              label: 'Edit profile',
                              onTap: widget.onEditNickname!,
                            ),
                          _ProfileMenuRow(
                            icon: Icons.settings_rounded,
                            tone: IconBadgeTone.cream,
                            label: 'Settings & account',
                            onTap: _openSettings,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSignOut != null) ...[
                      const SizedBox(height: 16),
                      LearnLiteButton(
                        label: 'Sign out',
                        icon: Icons.logout_rounded,
                        variant: LearnLiteButtonVariant.outlined,
                        onPressed: () async {
                          try {
                            await widget.onSignOut!();
                          } on AuthFailure catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSettings() async {
    final gateway = widget.gateway;
    final dictionaryGateway = gateway is DictionaryGateway
        ? gateway as DictionaryGateway
        : null;
    final accountEmail = gateway is FirebaseAuthGateway
        ? gateway.currentEmail
        : null;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (settingsContext) => Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            bottom: weaveAppBarBottom,
          ),
          body: SafeArea(
            child: SettingsScreen(
              gateway: gateway,
              profile: widget.profile,
              accountEmail: accountEmail,
              // After signing out, close Settings (and anything opened from
              // it) so the login screen underneath is shown immediately.
              onSignOut: widget.onSignOut == null
                  ? null
                  : () async {
                      await widget.onSignOut!();
                      if (settingsContext.mounted) {
                        Navigator.of(
                          settingsContext,
                        ).popUntil((route) => route.isFirst);
                      }
                    },
              onManageDownloads: dictionaryGateway == null
                  ? null
                  : () => Navigator.of(settingsContext).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Offline Content Packs'),
                            bottom: weaveAppBarBottom,
                          ),
                          body: SafeArea(
                            child: OfflineContentScreen(
                              gateway: dictionaryGateway,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.levelProgress});

  final LearnerProfile profile;
  final double levelProgress;

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
          const DecorativeBorder(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              children: [
                LearnerAvatar(
                  avatarId: profile.avatarId,
                  size: 104,
                  backgroundColor: AppColors.lightPink,
                  borderColor: AppColors.gold,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.nickname ?? profile.fullName,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  AvatarDesign.tryParse(profile.avatarId) == null
                      ? 'Design your avatar below.'
                      : 'Your LearnLite avatar',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Level ${profile.userLevel}',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${profile.xp} XP',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                LearnLiteProgressIndicator(
                  progress: levelProgress.clamp(0.0, 1.0),
                  color: AppColors.gold,
                  backgroundColor: AppColors.white.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${profile.xp.remainder(100)} of 100 XP toward the next level',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.65),
                    ),
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

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = IconBadgeTone.red,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconBadge(icon: icon, tone: tone, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ],
      ),
    ),
  );
}

class _AvatarStats extends StatelessWidget {
  const _AvatarStats({required this.profile, required this.rewardsFuture});

  final LearnerProfile profile;
  final Future<RewardsOverview> rewardsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RewardsOverview>(
      future: rewardsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Badge count could not be loaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.gray),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingCard(height: 170);
        }
        final earnedBadges = snapshot.data!.badges
            .where((badge) => badge.earned)
            .length;
        return LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  width: itemWidth,
                  icon: Icons.auto_stories_rounded,
                  label: 'Lessons completed',
                  value: '${profile.completedLessons}',
                  tone: IconBadgeTone.red,
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.workspace_premium_rounded,
                  label: 'Badges earned',
                  value: '$earnedBadges',
                  tone: IconBadgeTone.gold,
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.local_fire_department_rounded,
                  label: 'Daily streak',
                  value: '${profile.streak}',
                  tone: IconBadgeTone.red,
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.stars_rounded,
                  label: 'Current level',
                  value: '${profile.userLevel}',
                  tone: IconBadgeTone.gold,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
  Widget build(BuildContext context) {
    return SizedBox(
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
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
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
}

class _CustomizeAvatarCard extends StatelessWidget {
  const _CustomizeAvatarCard({required this.avatarId, this.onCustomize});

  final String? avatarId;
  final VoidCallback? onCustomize;

  @override
  Widget build(BuildContext context) {
    final design = AvatarDesign.tryParse(avatarId);
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      child: Row(
        children: [
          LearnerAvatar(avatarId: avatarId, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  design == null ? 'Create your avatar' : 'Your avatar',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Female or male character, skin tone, hair, outfit, woven '
                  'band, beads and background. No photo needed.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.gray),
                ),
                if (onCustomize != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('customize-avatar'),
                    onPressed: onCustomize,
                    icon: const Icon(Icons.brush_outlined, size: 18),
                    label: Text(
                      design == null ? 'Create avatar' : 'Customize avatar',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
