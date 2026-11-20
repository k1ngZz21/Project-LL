import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/pressable.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';
import 'lesson_screen.dart';

/// A tappable tool shortcut shown on the Lessons screen (Dictionary,
/// Offline downloads). At least 56 px tall, so it is an easy touch target.
class _LessonToolCard extends StatelessWidget {
  const _LessonToolCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.caption,
    this.tone = IconBadgeTone.red,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  final String caption;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, tone: tone, size: 40),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    required this.gateway,
    required this.onProgressChanged,
    this.isGuest = false,
    this.onModuleSelected,
    this.onOpenDictionary,
    this.onOpenDownloads,
    super.key,
  });

  final AuthGateway gateway;
  final VoidCallback onProgressChanged;
  final bool isGuest;
  final ValueChanged<LearningModule>? onModuleSelected;

  /// Opens the Dictionary. When null, the tool card is hidden.
  final VoidCallback? onOpenDictionary;

  /// Opens Offline downloads. When null, the tool card is hidden.
  final VoidCallback? onOpenDownloads;

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
                          const SectionHeader(
                            title: 'Learning Modules',
                            subtitle:
                                'Explore available language and culture lessons.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              StatusPill(
                                icon: Icons.offline_pin_rounded,
                                label:
                                    'Lessons stored on this device work offline.',
                              ),
                            ],
                          ),
                          if (widget.isGuest)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'Offline guest progress stays on this device and is not linked to Firebase.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                          FutureBuilder<String?>(
                            future: _syncNoticeFuture,
                            builder: (context, notice) {
                              if (notice.data == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.sync_problem_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        notice.data!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (widget.onOpenDictionary != null ||
                              widget.onOpenDownloads != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (widget.onOpenDictionary != null)
                                  Expanded(
                                    child: _LessonToolCard(
                                      key: const ValueKey(
                                        'lessons-open-dictionary',
                                      ),
                                      icon: Icons.translate_rounded,
                                      label: 'Dictionary',
                                      caption: 'Search Subanen words',
                                      onTap: widget.onOpenDictionary!,
                                    ),
                                  ),
                                if (widget.onOpenDictionary != null &&
                                    widget.onOpenDownloads != null)
                                  const SizedBox(width: 12),
                                if (widget.onOpenDownloads != null)
                                  Expanded(
                                    child: _LessonToolCard(
                                      key: const ValueKey(
                                        'lessons-open-downloads',
                                      ),
                                      icon: Icons.download_for_offline_rounded,
                                      label: 'Offline downloads',
                                      caption: 'Content packs',
                                      tone: IconBadgeTone.gold,
                                      onTap: widget.onOpenDownloads!,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchController,
                            onChanged: _searchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search modules',
                              prefixIcon: const Icon(Icons.search_rounded),
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
                            const LoadingCard(height: 150)
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
                              EntranceFade(
                                delayIndex: index,
                                child: _ModuleCard(
                                  number: index + 1,
                                  module: snapshot.data![index],
                                  showProgress: !widget.isGuest,
                                  onTap: () =>
                                      _openModule(snapshot.data![index]),
                                ),
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
    final textTheme = Theme.of(context).textTheme;
    final isComplete =
        module.lessonCount > 0 && module.completedLessons == module.lessonCount;
    return Semantics(
      button: true,
      child: LearnLiteCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModuleNumberTile(number: number),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODULE $number',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.goldDeep,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(module.title, style: textTheme.titleMedium),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.gray,
                        ),
                      ),
                    ],
                  ),
                  if (module.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      module.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      StatusPill(
                        icon: Icons.menu_book_rounded,
                        label:
                            '${module.lessonCount} ${module.lessonCount == 1 ? 'lesson' : 'lessons'}',
                      ),
                      const Spacer(),
                      if (showProgress)
                        StatusPill(
                          icon: isComplete
                              ? Icons.check_circle_rounded
                              : module.completedLessons > 0
                              ? Icons.timelapse_rounded
                              : Icons.radio_button_unchecked_rounded,
                          label: status,
                          tone: isComplete
                              ? IconBadgeTone.dark
                              : module.completedLessons > 0
                              ? IconBadgeTone.red
                              : IconBadgeTone.cream,
                        ),
                    ],
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 12),
                    LearnLiteProgressIndicator(progress: progress),
                    const SizedBox(height: 6),
                    Text(
                      '${module.completedLessons} of ${module.lessonCount} lessons completed',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.gray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A red gradient tile with the module number and a small gold diamond.
class _ModuleNumberTile extends StatelessWidget {
  const _ModuleNumberTile({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, AppColors.redDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 6,
          right: 6,
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(width: 6, height: 6, color: AppColors.gold),
          ),
        ),
        Text(
          '$number',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
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
        bottom: weaveAppBarBottom,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ModuleHeroCard(module: _module),
          if (widget.isGuest) ...[
            const SizedBox(height: 12),
            Text(
              'Guest quizzes and progress are stored on this device and are not linked to Firebase.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 24),
          const SectionHeader(title: 'Lessons'),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          for (final lesson in _module.lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonRow(
                lesson: lesson,
                isResume:
                    !lesson.completed &&
                    _module.lastLessonIndex == lesson.index,
                onTap: _isLoading ? null : () => _openLesson(lesson),
              ),
            ),
        ],
      ),
    );
  }
}

/// The dark module header: title, description and overall progress.
class _ModuleHeroCard extends StatelessWidget {
  const _ModuleHeroCard({required this.module});

  final LearningModule module;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = module.lessonCount == 0
        ? 0.0
        : (module.completedLessons / module.lessonCount).clamp(0.0, 1.0);
    return LearnLiteCard(
      backgroundColor: AppColors.charcoal,
      padding: EdgeInsets.zero,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(
                  icon: Icons.auto_stories_rounded,
                  tone: IconBadgeTone.dark,
                  size: 46,
                ),
                const SizedBox(height: 14),
                Text(
                  module.title,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                  ),
                ),
                if (module.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    module.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${module.completedLessons} of ${module.lessonCount} lessons',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LearnLiteProgressIndicator(
                  progress: progress,
                  color: AppColors.gold,
                  backgroundColor: AppColors.white.withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
          const DecorativeBorder(height: 8),
        ],
      ),
    );
  }
}

/// One lesson in a module: a step marker, the title and its status.
class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.isResume,
    required this.onTap,
  });

  final ModuleLesson lesson;
  final bool isResume;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = lesson.completed
        ? 'Completed'
        : isResume
        ? 'Resume'
        : 'Available';
    return LearnLiteCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      borderColor: isResume ? AppColors.primary.withValues(alpha: 0.4) : null,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lesson.completed
                  ? AppColors.primary
                  : isResume
                  ? AppColors.lightPink
                  : AppColors.creamSecondary,
              shape: BoxShape.circle,
            ),
            child: lesson.completed
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.white,
                    size: 22,
                  )
                : Text(
                    '${lesson.index + 1}',
                    style: TextStyle(
                      color: isResume ? AppColors.primary : AppColors.inkSoft,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: textTheme.labelMedium?.copyWith(
                    color: lesson.completed || isResume
                        ? AppColors.primary
                        : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isResume || !lesson.completed
                ? Icons.play_circle_fill_rounded
                : Icons.chevron_right_rounded,
            color: isResume ? AppColors.primary : AppColors.gray,
            size: isResume || !lesson.completed ? 30 : 24,
          ),
        ],
      ),
    );
  }
}
