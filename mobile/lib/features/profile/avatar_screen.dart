import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/learner_avatar.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
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
  int _selectedTab = 0;

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
                    const SizedBox(height: 18),
                    LearnLiteCard(
                      backgroundColor: AppColors.lightPink,
                      child: Column(
                        children: [
                          const LearnerAvatar(
                            size: 96,
                            backgroundColor: AppColors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.profile.nickname ?? widget.profile.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Avatar art is not available yet.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.gray),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AvatarStats(
                      profile: widget.profile,
                      rewardsFuture: _rewardsFuture,
                    ),
                    if (widget.onOpenRewards != null) ...[
                      const SizedBox(height: 12),
                      LearnLiteButton(
                        label: 'Badges & certificates',
                        icon: Icons.workspace_premium_outlined,
                        variant: LearnLiteButtonVariant.outlined,
                        onPressed: widget.onOpenRewards,
                      ),
                    ],
                    const SizedBox(height: 18),
                    LearnLiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Level ${widget.profile.userLevel}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              Text(
                                '${widget.profile.xp} XP',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          LinearProgressIndicator(
                            value: levelProgress,
                            color: AppColors.primary,
                            backgroundColor: AppColors.lightPink,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.profile.xp.remainder(100)} of 100 XP toward the next level',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.gray),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Customization'),
                    const SizedBox(height: 8),
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            onTap: (index) {
                              setState(() => _selectedTab = index);
                            },
                            tabs: const [
                              Tab(text: 'Outfit'),
                              Tab(text: 'Accessories'),
                              Tab(text: 'Background'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _LockedItems(tabIndex: _selectedTab),
                        ],
                      ),
                    ),
                    if (widget.onEditNickname != null) ...[
                      const SizedBox(height: 18),
                      LearnLiteButton(
                        label: 'Edit profile',
                        icon: Icons.edit_outlined,
                        variant: LearnLiteButtonVariant.outlined,
                        onPressed: widget.onEditNickname,
                      ),
                    ],
                    const SizedBox(height: 10),
                    LearnLiteButton(
                      label: 'Settings & account',
                      icon: Icons.settings_outlined,
                      variant: LearnLiteButtonVariant.outlined,
                      onPressed: _openSettings,
                    ),
                    if (widget.onSignOut != null) ...[
                      const SizedBox(height: 10),
                      LearnLiteButton(
                        label: 'Sign out',
                        icon: Icons.logout,
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
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: SettingsScreen(
              gateway: gateway,
              profile: widget.profile,
              accountEmail: accountEmail,
              onSignOut: widget.onSignOut,
              onManageDownloads: dictionaryGateway == null
                  ? null
                  : () => Navigator.of(settingsContext).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Offline Content Packs'),
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
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
                  icon: Icons.auto_stories_outlined,
                  label: 'Lessons completed',
                  value: '${profile.completedLessons}',
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.workspace_premium_outlined,
                  label: 'Badges earned',
                  value: '$earnedBadges',
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.local_fire_department_outlined,
                  label: 'Daily streak',
                  value: '${profile.streak}',
                ),
                _StatCard(
                  width: itemWidth,
                  icon: Icons.stars_outlined,
                  label: 'Current level',
                  value: '${profile.userLevel}',
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
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.gray),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedItems extends StatelessWidget {
  const _LockedItems({required this.tabIndex});

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final title = switch (tabIndex) {
      0 => 'Outfits are locked',
      1 => 'Accessories are locked',
      _ => 'Backgrounds are locked',
    };
    return LearnLiteCard(
      backgroundColor: AppColors.cream,
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.gray, size: 30),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Customization items will appear here when approved assets are available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}
