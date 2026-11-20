import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/user_message.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.gateway,
    required this.profile,
    this.accountEmail,
    this.onSignOut,
    this.onManageDownloads,
    super.key,
  });

  final AuthGateway gateway;
  final LearnerProfile profile;
  final String? accountEmail;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onManageDownloads;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<_StorageSummary?> _storageFuture;
  bool _isSendingReset = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _storageFuture = _loadStorage();
  }

  Future<_StorageSummary?> _loadStorage() async {
    final gateway = widget.gateway;
    if (gateway is! DictionaryGateway) return null;
    final dictionaryGateway = gateway as DictionaryGateway;
    final packs = await dictionaryGateway.downloadedContentPacks();
    final bytes = await dictionaryGateway.offlineStorageBytes();
    return _StorageSummary(downloadedPacks: packs.length, bytes: bytes);
  }

  Future<void> _sendPasswordReset() async {
    final email = widget.accountEmail?.trim();
    if (email == null || email.isEmpty || _isSendingReset) return;
    setState(() => _isSendingReset = true);
    try {
      await widget.gateway.sendPasswordResetEmail(email);
      if (mounted) {
        _showMessage(
          'If an account matches that email, a password reset link is on its way.',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(gateway: widget.gateway),
    );
    if (changed == true && mounted) {
      _showMessage('Your password has been updated.');
    }
  }

  Future<void> _signOut() async {
    final signOut = widget.onSignOut;
    if (signOut == null || _isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await signOut();
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Settings & account'),
              const SizedBox(height: 16),
              LearnLiteCard(
                backgroundColor: AppColors.charcoal,
                padding: EdgeInsets.zero,
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learner account',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.gold),
                          ),
                          const SizedBox(height: 14),
                          _AccountDetail(
                            label: 'Name',
                            value: widget.profile.fullName,
                          ),
                          _AccountDetail(
                            label: 'Username',
                            value: widget.profile.username,
                          ),
                          _AccountDetail(
                            label: 'Email',
                            value: widget.accountEmail ?? 'Not available',
                          ),
                        ],
                      ),
                    ),
                    const DecorativeBorder(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Security'),
              const SizedBox(height: 12),
              LearnLiteCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const ValueKey('settings-change-password'),
                      icon: Icons.lock_outline_rounded,
                      label: 'Change password',
                      onTap: _changePassword,
                    ),
                    const Divider(indent: 70),
                    _SettingsRow(
                      key: const ValueKey('settings-password-reset'),
                      icon: Icons.lock_reset_rounded,
                      tone: IconBadgeTone.gold,
                      label: 'Send password reset email',
                      busy: _isSendingReset,
                      onTap: widget.accountEmail == null || _isSendingReset
                          ? null
                          : _sendPasswordReset,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(title: 'Offline learning'),
              const SizedBox(height: 12),
              LearnLiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconBadge(
                          icon: Icons.offline_pin_rounded,
                          tone: IconBadgeTone.gold,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Lessons, vocabulary, and learning progress are kept on '
                            'this device. Signing out does not erase saved learning '
                            'records.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FutureBuilder<_StorageSummary?>(
                      future: _storageFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator(
                            color: AppColors.primary,
                          );
                        }
                        if (snapshot.hasError) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userMessage(
                                  snapshot.error,
                                  fallback:
                                      'Downloaded storage could not be loaded right now.',
                                ),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _storageFuture = _loadStorage();
                                }),
                                child: const Text('Try again'),
                              ),
                            ],
                          );
                        }
                        final storage = snapshot.data;
                        if (storage == null) {
                          return const EmptyState(
                            icon: Icons.storage_outlined,
                            title: 'Storage information unavailable',
                            message:
                                'Local content services are not configured.',
                          );
                        }
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.creamSecondary.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.storage_rounded,
                                size: 18,
                                color: AppColors.inkSoft,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${storage.downloadedPacks} downloaded packs · '
                                  '${_formatSize(storage.bytes)}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (widget.onManageDownloads != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onManageDownloads,
                          icon: const Icon(
                            Icons.download_for_offline_outlined,
                          ),
                          label: const Text('Manage offline content'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const ValueKey('settings-sign-out'),
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: _isSigningOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _AccountDetail extends StatelessWidget {
  const _AccountDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.white.withValues(alpha: 0.55)),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = IconBadgeTone.red,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final IconBadgeTone tone;
  final bool busy;

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
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: onTap == null && !busy ? AppColors.gray : null,
              ),
            ),
          ),
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ],
      ),
    ),
  );
}

class _StorageSummary {
  const _StorageSummary({required this.downloadedPacks, required this.bytes});

  final int downloadedPacks;
  final int bytes;
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.gateway});

  final AuthGateway gateway;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a new password.';
    if (value.length < 10 ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use 10+ characters with uppercase, lowercase, and a number.';
    }
    if (value == _currentPassword.text) {
      return 'Choose a password different from your current one.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('current-password'),
              controller: _currentPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your current password.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-password'),
              controller: _newPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.password_rounded),
              ),
              validator: _validateNewPassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('confirm-new-password'),
              controller: _confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (value) =>
                  value != _newPassword.text ? 'Passwords do not match.' : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _isSaving ? null : _save,
        child: _isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Update password'),
      ),
    ],
  );
}
