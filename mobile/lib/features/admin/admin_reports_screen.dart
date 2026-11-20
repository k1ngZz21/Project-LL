import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../content/content_gateway.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({required this.gateway, super.key});

  final AdminGateway gateway;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late Future<AdminDashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.gateway.fetchAdminSummary();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = widget.gateway.fetchAdminSummary();
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(title: 'Reports and Upload Status'),
                  ),
                  IconButton(
                    tooltip: 'Refresh reports',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Statistics are calculated from current database records.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: 20),
              FutureBuilder<AdminDashboardSummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return LearnLiteCard(
                      backgroundColor: AppColors.lightPink,
                      child: Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    );
                  }
                  final report = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            title: 'Total modules',
                            value: report.totalModules,
                            icon: Icons.auto_stories_outlined,
                          ),
                          _MetricCard(
                            title: 'Published modules',
                            value: report.publishedModules,
                            icon: Icons.publish_outlined,
                          ),
                          _MetricCard(
                            title: 'Total lessons',
                            value: report.totalLessons,
                            icon: Icons.menu_book_outlined,
                          ),
                          _MetricCard(
                            title: 'Verified dictionary entries',
                            value: report.verifiedDictionaryEntries,
                            icon: Icons.verified_outlined,
                          ),
                          _MetricCard(
                            title: 'Uploaded resources',
                            value: report.uploadedResources,
                            icon: Icons.attach_file,
                          ),
                          _MetricCard(
                            title: 'Quiz attempts',
                            value: report.quizAttempts,
                            icon: Icons.quiz_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Activity · last 7 days',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      LearnLiteCard(
                        child: report.activity.isEmpty
                            ? const Text('No activity records are available.')
                            : _ActivityChart(activity: report.activity),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Recent upload activity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      if (report.recentUploads.isEmpty)
                        const EmptyState(
                          icon: Icons.cloud_upload_outlined,
                          title: 'No uploads yet',
                          message: 'Uploaded resources will appear here after an administrator adds them.',
                        )
                      else
                        LearnLiteCard(
                          child: Column(
                            children: [
                              for (final (index, upload)
                                  in report.recentUploads.indexed) ...[
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.lightPink,
                                    foregroundColor: AppColors.primary,
                                    child: Icon(Icons.attach_file),
                                  ),
                                  title: Text(upload.name),
                                  subtitle: Text(
                                    '${upload.mediaType} · ${_formatSize(upload.sizeBytes)}'
                                    '${upload.createdAt == null ? '' : ' · ${upload.createdAt!.toLocal().toString().substring(0, 16)}'}',
                                  ),
                                  trailing: const Chip(
                                    label: Text('Uploaded'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                if (index < report.recentUploads.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: LearnLiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.darkBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.activity});

  final List<Map<String, dynamic>> activity;

  @override
  Widget build(BuildContext context) {
    final maximum = activity.fold<int>(
      0,
      (value, item) => [
        value,
        _int(item['uploads']),
        _int(item['quiz_attempts']),
      ].reduce((a, b) => a > b ? a : b),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(AppColors.primary, 'Uploads'),
            const SizedBox(width: 20),
            _legend(AppColors.gold, 'Quiz attempts'),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in activity)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${_int(day['uploads'])}/${_int(day['quiz_attempts'])}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _bar(
                                _int(day['uploads']),
                                maximum,
                                AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              _bar(
                                _int(day['quiz_attempts']),
                                maximum,
                                AppColors.gold,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _shortDate(day['date'] as String?),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(int value, int maximum, Color color) => Flexible(
    child: FractionallySizedBox(
      heightFactor: maximum == 0 ? 0 : value / maximum,
      child: Container(
        width: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
    ),
  );

  Widget _legend(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

String _shortDate(String? value) {
  if (value == null || value.length < 10) return '';
  return value.substring(5);
}

String _formatSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

int _int(dynamic value) => value is int ? value : 0;
