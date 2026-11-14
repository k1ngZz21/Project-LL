import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';
import 'lesson_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    required this.gateway,
    required this.onProgressChanged,
    this.isGuest = false,
    this.onModuleSelected,
    super.key,
  });

  final AuthGateway gateway;
  final VoidCallback onProgressChanged;
  final bool isGuest;
  final ValueChanged<LearningModule>? onModuleSelected;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  late Future<List<LearningModule>> _modulesFuture;
  late Future<String?> _syncNoticeFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _modulesFuture = widget.gateway.fetchModules();
    _syncNoticeFuture = _loadSyncNotice(_modulesFuture);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _search = value.trim();
        _modulesFuture = widget.gateway.fetchModules(search: _search);
        _syncNoticeFuture = _loadSyncNotice(_modulesFuture);
      });
    });
  }

  Future<void> _refresh() async {
    final future = widget.gateway.fetchModules(search: _search);
    setState(() {
      _modulesFuture = future;
      _syncNoticeFuture = _loadSyncNotice(future);
    });
    await future;
  }

  Future<String?> _loadSyncNotice(
    Future<List<LearningModule>> modulesFuture,
  ) async {
    try {
      await modulesFuture;
    } on AuthFailure {
      // The module list presents its own error or offline-cache state.
    }
    final gateway = widget.gateway;
    if (gateway is OfflineSyncStatusGateway) {
      return (gateway as OfflineSyncStatusGateway).offlineSyncNotice();
    }
    return null;
  }

  Future<void> _openModule(LearningModule module) async {
    try {
      final detail = await widget.gateway.fetchModule(module.id);
      if (!mounted) return;
      final updated = await Navigator.of(context).push<LearningModule>(
        MaterialPageRoute(
          builder: (_) => ModuleDetailScreen(
            gateway: widget.gateway,
            module: detail,
            isGuest: widget.isGuest,
          ),
        ),
      );
      if (updated != null) {
        if (!widget.isGuest) widget.onProgressChanged();
        await _refresh();
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = ResponsiveLayout.horizontalPadding(
          constraints.maxWidth,
        );
        return FutureBuilder<List<LearningModule>>(
          future: _modulesFuture,
          builder: (context, snapshot) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  26,
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
                          const SectionHeader(title: 'Learning Modules'),
                          const SizedBox(height: 8),
                          if (widget.isGuest)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Offline guest progress stays on this device and is not linked to Firebase.',
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.offline_pin_outlined,
                                  size: 18,
                                  color: AppColors.gray,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Lessons stored on this device work offline.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FutureBuilder<String?>(
                            future: _syncNoticeFuture,
                            builder: (context, notice) {
                              if (notice.data == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  notice.data!,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                          Text(
                            'Explore available language and culture lessons.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.gray),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchController,
                            onChanged: _searchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search modules',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchChanged('');
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else if (snapshot.hasError)
                            _LoadError(
                              onRetry: () {
                                setState(() {
                                  _modulesFuture = widget.gateway.fetchModules(
                                    search: _search,
                                  );
                                  _syncNoticeFuture = _loadSyncNotice(
                                    _modulesFuture,
                                  );
                                });
                              },
                            )
                          else if ((snapshot.data ?? []).isEmpty)
                            EmptyState(
                              icon: Icons.auto_stories_outlined,
                              title: _search.isEmpty
                                  ? 'No learning modules yet'
                                  : 'No modules found',
                              message: _search.isEmpty
                                  ? 'New modules will appear here after approved learning content is uploaded.'
                                  : 'Try a different search.',
                            )
                          else ...[
                            for (
                              var index = 0;
                              index < snapshot.data!.length;
                              index++
                            ) ...[
                              _ModuleCard(
                                number: index + 1,
                                module: snapshot.data![index],
                                showProgress: !widget.isGuest,
                                onTap: () => _openModule(snapshot.data![index]),
                              ),
                              if (index < snapshot.data!.length - 1)
                                const SizedBox(height: 14),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.number,
    required this.module,
    required this.showProgress,
    required this.onTap,
  });

  final int number;
  final LearningModule module;
  final bool showProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = module.lessonCount == 0
        ? 0.0
        : module.completedLessons / module.lessonCount;
    final status = module.completedLessons == module.lessonCount
        ? 'Completed'
        : module.completedLessons > 0
        ? 'In progress'
        : 'Not started';
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: LearnLiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.lightPink,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.gray),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                module.description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.gray),
              ),
              if (showProgress) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${module.lessonCount} ${module.lessonCount == 1 ? 'lesson' : 'lessons'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: module.completedLessons > 0
                            ? AppColors.primary
                            : AppColors.gray,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LearnLiteProgressIndicator(progress: progress),
                const SizedBox(height: 5),
                Text(
                  '${module.completedLessons} of ${module.lessonCount} lessons completed',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.gray),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Modules could not be loaded',
          message: 'Check your connection and try again.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class ModuleDetailScreen extends StatefulWidget {
  const ModuleDetailScreen({
    required this.gateway,
    required this.module,
    this.isGuest = false,
    super.key,
  });

  final AuthGateway gateway;
  final LearningModule module;
  final bool isGuest;

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  late LearningModule _module;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _module = widget.module;
  }

  Future<void> _openLesson(ModuleLesson lesson) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.gateway.startModuleLesson(
        _module.id,
        lesson.index,
      );
      if (!mounted) return;
      setState(() => _module = updated);
      final activeLesson = updated.lessons[lesson.index];
      final completedModule = await Navigator.of(context).push<LearningModule>(
        MaterialPageRoute(
          builder: (_) => ModuleLessonScreen(
            gateway: widget.gateway,
            module: updated,
            lesson: activeLesson,
            isGuest: widget.isGuest,
          ),
        ),
      );
      if (completedModule != null && mounted) {
        setState(() => _module = completedModule);
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _closeModule() => Navigator.of(context).pop(_module);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_module.title),
        leading: IconButton(
          tooltip: 'Back to modules',
          onPressed: _closeModule,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_module.description),
          if (widget.isGuest) ...[
            const SizedBox(height: 8),
            const Text(
              'Guest quizzes and progress are stored on this device and are not linked to Firebase.',
            ),
          ],
          const SizedBox(height: 18),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.primary),
            ),
          if (_isLoading)
            const LinearProgressIndicator(color: AppColors.primary),
          for (final lesson in _module.lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LearnLiteCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    lesson.completed
                        ? Icons.check_circle
                        : Icons.play_circle_outline,
                    color: lesson.completed
                        ? AppColors.primary
                        : AppColors.gray,
                  ),
                  title: Text(lesson.title),
                  subtitle: Text(
                    lesson.completed
                        ? 'Completed'
                        : _module.lastLessonIndex == lesson.index
                        ? 'Resume'
                        : 'Available',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isLoading ? null : () => _openLesson(lesson),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
