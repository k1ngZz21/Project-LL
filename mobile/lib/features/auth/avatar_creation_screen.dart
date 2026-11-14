import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_text_field.dart';
import '../../widgets/learner_avatar.dart';
import 'auth_gateway.dart';

class AvatarCreationScreen extends StatefulWidget {
  const AvatarCreationScreen({
    required this.profile,
    required this.authGateway,
    required this.onSaved,
    this.onSignOut,
    super.key,
  });

  final LearnerProfile profile;
  final AuthGateway authGateway;
  final ValueChanged<LearnerProfile> onSaved;
  final Future<void> Function()? onSignOut;

  @override
  State<AvatarCreationScreen> createState() => _AvatarCreationScreenState();
}

class _AvatarCreationScreenState extends State<AvatarCreationScreen> {
  late final TextEditingController _nicknameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.profile.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nicknameController.text.trim().length > 40) {
      setState(() {
        _errorMessage = 'Nickname must be 40 characters or fewer.';
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = LearnerProfile(
        username: widget.profile.username,
        fullName: widget.profile.fullName,
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        avatarId: widget.profile.avatarId,
        outfitColor: widget.profile.outfitColor,
        avatarCompleted: true,
        userLevel: widget.profile.userLevel,
        xp: widget.profile.xp,
        streak: widget.profile.streak,
        completedLessons: widget.profile.completedLessons,
      );
      final saved = await widget.authGateway.updateAvatarProfile(updated);
      widget.onSaved(saved);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.onSignOut?.call();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize your profile'),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = ResponsiveLayout.horizontalPadding(
              constraints.maxWidth,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create Your Avatar',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make your learning space your own.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.gray),
                      ),
                      const SizedBox(height: 20),
                      LearnLiteCard(
                        child: Column(
                          children: [
                            LearnerAvatar(
                              size: 112,
                              backgroundColor: AppColors.lightPink,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nicknameController.text.trim().isEmpty
                                  ? 'Your avatar'
                                  : _nicknameController.text.trim(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 20),
                            const DecorativeBorder(),
                            const SizedBox(height: 20),
                            LearnLiteTextField(
                              controller: _nicknameController,
                              label: 'Nickname (optional)',
                              hint: 'Choose a nickname',
                              prefixIcon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              validator: (value) =>
                                  value != null && value.trim().length > 40
                                  ? 'Nickname must be 40 characters or fewer.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LearnLiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose an avatar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            const EmptyState(
                              icon: Icons.face_retouching_natural_outlined,
                              title: 'Avatar designs are coming soon',
                              message: 'A generic avatar is shown until approved avatar designs are added.',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Outfits and colors will unlock when customization items are available.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.gray),
                            ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      LearnLiteButton(
                        label: widget.profile.avatarCompleted
                            ? 'Save Changes'
                            : 'Start Learning',
                        icon: widget.profile.avatarCompleted
                            ? Icons.save_outlined
                            : Icons.arrow_forward,
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
