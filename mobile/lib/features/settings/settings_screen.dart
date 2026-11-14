import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learner account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('settings-password-reset'),
                      onPressed:
                          widget.accountEmail == null || _isSendingReset
                          ? null
                          : _sendPasswordReset,
                      icon: _isSendingReset
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_outlined),
                      label: const Text('Send password reset email'),
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
                      'Offline learning',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lessons, vocabulary, and learning progress are kept on '
                      'this device. Signing out does not erase saved learning '
                      'records.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
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
                                'Downloaded storage could not be loaded: '
                                '${snapshot.error}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _storageFuture = _loadStorage(),
                                ),
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
                        return Text(
                          '${storage.downloadedPacks} downloaded packs · '
                          '${_formatSize(storage.bytes)}',
                        );
                      },
                    ),
                    if (widget.onManageDownloads != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onManageDownloads,
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Manage offline content'),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonalIcon(
                  key: const ValueKey('settings-sign-out'),
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: _isSigningOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
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
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.gray),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _StorageSummary {
  const _StorageSummary({required this.downloadedPacks, required this.bytes});

  final int downloadedPacks;
  final int bytes;
}
