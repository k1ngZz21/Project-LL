import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late Future<RewardsOverview> _rewardsFuture;
  String? _busyCertificateId;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = widget.gateway.fetchRewards();
  }

  Future<void> _exportCertificate(
    LearnerCertificate certificate, {
    required bool share,
  }) async {
    setState(() => _busyCertificateId = certificate.certificateId);
    try {
      final bytes = await widget.gateway.fetchCertificatePdf(
        certificate.certificateId,
      );
      final filename = 'LearnLite-certificate-${certificate.certificateId}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
      }
    } on AuthFailure catch (error) {
      if (mounted) _showMessage(error.message);
    } on Exception {
      if (mounted) {
        _showMessage(
          share
              ? 'The certificate could not be shared. Try downloading the PDF.'
              : 'The certificate PDF could not be opened. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyCertificateId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _previewCertificate(LearnerCertificate certificate) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Certificate of Module Completion',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(certificate.learnerName, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(certificate.moduleTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Issued ${_formatDate(certificate.issuedAt)}',
              style: const TextStyle(color: AppColors.gray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _showBadgeDetails(RewardBadge badge) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(badge.title),
        content: Text(
          '${badge.description}\n\n'
          '${badge.earned ? 'Earned' : 'Progress: ${badge.progress} of ${badge.target}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ResponsiveLayout.horizontalPadding(
          constraints.maxWidth,
        );
        return FutureBuilder<RewardsOverview>(
          future: _rewardsFuture,
          builder: (context, snapshot) {
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
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else if (snapshot.hasError)
                          _RewardsLoadError(
                            onRetry: () => setState(
                              () => _rewardsFuture = widget.gateway
                                  .fetchRewards(),
                            ),
                          )
                        else ...[
                          _buildBadgeCollection(snapshot.data!),
                          const SizedBox(height: 28),
                          _buildCertificates(snapshot.data!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBadgeCollection(RewardsOverview overview) {
    final earnedCount = overview.badges.where((badge) => badge.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Your badges',
          trailing: Text(
            '$earnedCount of ${overview.badges.length} earned',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.gray),
          ),
        ),
        const SizedBox(height: 14),
        if (overview.badges.isEmpty)
          const EmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'No badges available yet',
            message: 'Badges will appear here when they are available.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 3 : 2;
              final spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final badge in overview.badges)
                    SizedBox(
                      width: width,
                      child: _BadgeCard(
                        badge: badge,
                        onTap: () => _showBadgeDetails(badge),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildCertificates(RewardsOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Certificates'),
        const SizedBox(height: 14),
        if (overview.certificates.isEmpty)
          const EmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'No certificates yet',
            message: 'Complete every lesson in a published module to earn a completion certificate.',
          )
        else
          for (final certificate in overview.certificates) ...[
            _CertificateCard(
              certificate: certificate,
              isBusy: _busyCertificateId == certificate.certificateId,
              onPreview: () => _previewCertificate(certificate),
              onDownload: () => _exportCertificate(certificate, share: false),
              onShare: () => _exportCertificate(certificate, share: true),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.onTap});

  final RewardBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medalColor = badge.earned ? AppColors.gold : const Color(0xFFDCD6CC);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LearnLiteCard(
          padding: const EdgeInsets.all(14),
          backgroundColor: badge.earned ? AppColors.white : AppColors.cream,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 24,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 5),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: 10),
              if (!badge.earned) ...[
                LinearProgressIndicator(
                  value: badge.target == 0
                      ? 0
                      : (badge.progress / badge.target).clamp(0.0, 1.0),
                  color: AppColors.primary,
                  backgroundColor: AppColors.lightPink,
                ),
                const SizedBox(height: 4),
                Text(
                  'Locked · ${badge.progress} of ${badge.target}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.gray),
                ),
              ] else
                Text(
                  'Earned',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.certificate,
    required this.isBusy,
    required this.onPreview,
    required this.onDownload,
    required this.onShare,
  });

  final LearnerCertificate certificate;
  final bool isBusy;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return LearnLiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.moduleTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Issued ${certificate.issuedAt.toLocal().toString().split(' ').first}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.gray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: isBusy ? null : onPreview,
                child: const Text('Preview'),
              ),
              FilledButton.tonal(
                onPressed: isBusy ? null : onDownload,
                child: isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Download PDF'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onShare,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardsLoadError extends StatelessWidget {
  const _RewardsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Rewards could not be loaded',
          message: 'Check your connection and try again.',
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
