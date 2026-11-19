import 'package:flutter/material.dart';

import '../core/learning_snapshot.dart';
import '../features/auth/auth_gateway.dart';
import '../features/auth/avatar_creation_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/progress_screen.dart';
import '../features/content/content_gateway.dart';
import '../features/content/dictionary_screen.dart';
import '../features/content/local_vocabulary_screen.dart';
import '../features/content/offline_content_screen.dart';
import '../features/modules/lesson_screen.dart';
import '../features/modules/modules_screen.dart';
import '../features/profile/avatar_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/tutor/tutor_gateway.dart';
import '../features/tutor/tutor_screen.dart';
import '../features/content/vocabulary_practice_screen.dart';
import '../widgets/decorative_border.dart';
import '../widgets/empty_state.dart';
import '../widgets/learnlite_brand_mark.dart';
import 'app_colors.dart';

enum AppDestination { home, learn, quiz, progress, profile }

class AppShell extends StatefulWidget {
  const AppShell({
    required this.profile,
    required this.authGateway,
    this.onProfileUpdated,
    this.onSignOut,
    this.onSignIn,
    this.isGuest = false,
    super.key,
  });

  final LearnerProfile profile;
  final AuthGateway authGateway;
  final ValueChanged<LearnerProfile>? onProfileUpdated;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onSignIn;
  final bool isGuest;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination;
  late LearnerProfile _profile;
  bool _isOpeningLearning = false;

  @override
  void initState() {
    super.initState();
    _destination = widget.isGuest ? AppDestination.learn : AppDestination.home;
    _profile = widget.profile;
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile) _profile = widget.profile;
  }

  void _selectDestination(AppDestination destination) {
    setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.gold,
        title: const Row(
          children: [
            LearnLiteBrandMark(size: 32),
            SizedBox(width: 9),
            Text('LearnLite'),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(10),
          child: DecorativeBorder(height: 10),
        ),
        actions: [
          IconButton(
            tooltip: 'Open AI Tutor',
            onPressed: _openTutor,
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More tools',
            onSelected: (value) {
              switch (value) {
                case 'dictionary':
                  _openDictionary();
                case 'downloads':
                  _openDownloads();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'dictionary',
                child: ListTile(
                  leading: Icon(Icons.translate_outlined),
                  title: Text('Dictionary'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'downloads',
                child: ListTile(
                  leading: Icon(Icons.download_for_offline_outlined),
                  title: Text('Offline downloads'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          if (widget.isGuest)
            TextButton(
              onPressed: widget.onSignIn,
              child: const Text('Sign in'),
            ),
        ],
      ),
      body: SafeArea(child: _buildDestination(context)),
      bottomNavigationBar: LearnLiteNavigationBar(
        destination: _destination,
        onDestinationSelected: _selectDestination,
      ),
    );
  }

  Widget _buildDestination(BuildContext context) {
    return switch (_destination) {
      AppDestination.home => DashboardScreen(
        snapshot: LearningSnapshot(
          fullName: _profile.fullName,
          username: _profile.username,
          nickname: _profile.nickname,
          avatarUrl: null,
          userLevel: _profile.userLevel,
          xp: _profile.xp,
          streak: _profile.streak,
          completedLessons: _profile.completedLessons,
        ),
        gateway: widget.authGateway,
        onOpenModules: () => _selectDestination(AppDestination.learn),
        onContinueLearning: _continueLearning,
        onOpenRewards: _openRewards,
        onOpenVocabulary: _openVocabularyReference,
      ),
      AppDestination.learn => ModulesScreen(
        key: const ValueKey(AppDestination.learn),
        gateway: widget.authGateway,
        onProgressChanged: _reloadProfile,
        isGuest: widget.isGuest,
      ),
      AppDestination.quiz => _buildQuiz(),
      AppDestination.progress => ProgressScreen(
        snapshot: _learningSnapshot,
        gateway: widget.authGateway,
        onOpenRewards: _openRewards,
      ),
      AppDestination.profile => _buildProfile(),
    };
  }

  LearningSnapshot get _learningSnapshot => LearningSnapshot(
    fullName: _profile.fullName,
    username: _profile.username,
    nickname: _profile.nickname,
    avatarUrl: null,
    userLevel: _profile.userLevel,
    xp: _profile.xp,
    streak: _profile.streak,
    completedLessons: _profile.completedLessons,
  );

  Widget _buildQuiz() {
    final gateway = widget.authGateway;
    if (gateway is! DictionaryGateway) {
      return _emptyPage(
        icon: Icons.quiz_outlined,
        title: 'Quiz unavailable',
        message: 'Vocabulary practice is not configured.',
      );
    }
    return VocabularyPracticeScreen(
      gateway: gateway as DictionaryGateway,
      startInQuiz: true,
      showAppBar: false,
    );
  }

  Widget _buildProfile() {
    if (widget.isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.person_outline,
            title: 'Guest learner',
            message: 'Your offline lessons and progress stay on this device. Sign in to manage your learner profile.',
            action: FilledButton(
              onPressed: widget.onSignIn,
              child: const Text('Sign in'),
            ),
          ),
        ),
      );
    }
    return AvatarScreen(
      key: const ValueKey(AppDestination.profile),
      profile: _profile,
      gateway: widget.authGateway,
      onEditNickname: _editAvatar,
      onOpenRewards: _openRewards,
      onSignOut: widget.onSignOut,
    );
  }

  Widget _buildDictionary() {
    final gateway = widget.authGateway;
    if (gateway is! DictionaryGateway) {
      return _emptyPage(
        icon: Icons.menu_book_outlined,
        title: 'Dictionary unavailable',
        message: 'Dictionary services are not configured.',
      );
    }
    return DictionaryScreen(gateway: gateway as DictionaryGateway);
  }

  void _openDictionary() {
    _openToolPage(title: 'Dictionary', child: _buildDictionary());
  }

  void _openDownloads() {
    _openToolPage(title: 'Offline downloads', child: _buildDownloads());
  }

  void _openVocabularyReference() {
    final gateway = widget.authGateway;
    if (gateway is! DictionaryGateway) {
      _openDictionary();
      return;
    }
    _openToolPage(
      title: 'Offline Vocabulary Reference',
      child: LocalVocabularyScreen(gateway: gateway as DictionaryGateway),
    );
  }

  void _openToolPage({required String title, required Widget child}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(10),
              child: DecorativeBorder(height: 10),
            ),
          ),
          body: SafeArea(child: child),
        ),
      ),
    );
  }

  Future<void> _continueLearning(LearningModule module) async {
    if (_isOpeningLearning) return;
    setState(() => _isOpeningLearning = true);
    try {
      final latestModule = await widget.authGateway.fetchModule(module.id);
      if (!mounted) return;
      if (latestModule.lessons.isEmpty) {
        _selectDestination(AppDestination.learn);
        return;
      }

      final nextLessonIndex = latestModule.lessons.indexWhere(
        (lesson) => !lesson.completed,
      );
      final lastLessonIndex = latestModule.lastLessonIndex;
      final canResumeLastLesson =
          lastLessonIndex != null &&
          lastLessonIndex >= 0 &&
          lastLessonIndex < latestModule.lessons.length &&
          !latestModule.lessons[lastLessonIndex].completed;
      final lessonIndex = canResumeLastLesson
          ? lastLessonIndex
          : nextLessonIndex >= 0
          ? nextLessonIndex
          : (lastLessonIndex != null &&
                lastLessonIndex >= 0 &&
                lastLessonIndex < latestModule.lessons.length)
          ? lastLessonIndex
          : 0;
      final startedModule = await widget.authGateway.startModuleLesson(
        latestModule.id,
        lessonIndex,
      );
      if (!mounted) return;
      final updatedModule = await Navigator.of(context).push<LearningModule>(
        MaterialPageRoute(
          builder: (_) => ModuleLessonScreen(
            gateway: widget.authGateway,
            module: startedModule,
            lesson: startedModule.lessons[lessonIndex],
            isGuest: widget.isGuest,
          ),
        ),
      );
      if (updatedModule != null && mounted && !widget.isGuest) {
        await _reloadProfile();
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isOpeningLearning = false);
    }
  }

  Widget _buildDownloads() {
    final gateway = widget.authGateway;
    if (gateway is! DictionaryGateway) {
      return _emptyPage(
        icon: Icons.download_for_offline_outlined,
        title: 'Downloads unavailable',
        message: 'Offline content services are not configured.',
      );
    }
    return OfflineContentScreen(gateway: gateway as DictionaryGateway);
  }

  void _openRewards() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Badges & Certificates')),
          body: RewardsScreen(gateway: widget.authGateway),
        ),
      ),
    );
  }

  void _openTutor() {
    final gateway = widget.authGateway;
    final tokenProvider = gateway is TutorTokenProvider
        ? (gateway as TutorTokenProvider).tutorIdToken
        : null;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TutorScreen(
          isGuest: widget.isGuest,
          idTokenProvider: tokenProvider,
          onSignIn: widget.onSignIn,
        ),
      ),
    );
  }

  Future<void> _editAvatar() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AvatarCreationScreen(
          profile: _profile,
          authGateway: widget.authGateway,
          onSaved: (updated) {
            setState(() => _profile = updated);
            widget.onProfileUpdated?.call(updated);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _reloadProfile() async {
    try {
      final updated = await widget.authGateway.fetchProfile();
      if (mounted) setState(() => _profile = updated);
      widget.onProfileUpdated?.call(updated);
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Widget _emptyPage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: EmptyState(icon: icon, title: title, message: message),
      ),
    );
  }
}

class LearnLiteNavigationBar extends StatelessWidget {
  const LearnLiteNavigationBar({
    required this.destination,
    required this.onDestinationSelected,
    super.key,
  });

  final AppDestination destination;
  final ValueChanged<AppDestination> onDestinationSelected;

  static const _destinations = [
    _NavigationItem(
      destination: AppDestination.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavigationItem(
      destination: AppDestination.learn,
      label: 'Lessons',
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories,
    ),
    _NavigationItem(
      destination: AppDestination.quiz,
      label: 'Quiz',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz,
    ),
    _NavigationItem(
      destination: AppDestination.progress,
      label: 'Progress',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
    ),
    _NavigationItem(
      destination: AppDestination.profile,
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const destinations = _destinations;
    final selectedIndex = destinations.indexWhere(
      (item) => item.destination == destination,
    );

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) =>
          onDestinationSelected(destinations[index].destination),
      destinations: [
        for (final item in destinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.destination,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AppDestination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
