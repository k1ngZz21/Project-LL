import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/display_format.dart';
import '../../core/workbook_modules.dart';
import '../../widgets/answer_option_tile.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';
import '../content/local_vocabulary.dart';

enum _LessonView { lesson, quiz, results }

class ModuleLessonScreen extends StatefulWidget {
  const ModuleLessonScreen({
    required this.gateway,
    required this.module,
    required this.lesson,
    this.isGuest = false,
    super.key,
  });

  final AuthGateway gateway;
  final LearningModule module;
  final ModuleLesson lesson;
  final bool isGuest;

  @override
  State<ModuleLessonScreen> createState() => _ModuleLessonScreenState();
}

class _ModuleLessonScreenState extends State<ModuleLessonScreen> {
  final _audioPlayer = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerSubscription;
  late LearningModule _module;
  late ModuleLesson _lesson;
  late Future<List<QuizResult>> _quizHistory;
  late Future<List<LocalVocabularyEntry>> _lessonWords;
  List<int> _answers = [];
  QuizResult? _result;
  _LessonView _view = _LessonView.lesson;
  PlayerState _playerState = PlayerState.stopped;
  bool _isSaving = false;
  bool _showReview = false;
  String? _errorMessage;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _module = widget.module;
    _lesson = widget.lesson;
    _quizHistory = _loadQuizHistory();
    _lessonWords = _loadLessonWords();
    _playerSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    unawaited(_playerSubscription.cancel());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<List<QuizResult>> _loadQuizHistory() {
    if (_lesson.quiz.isEmpty) {
      return Future.value(const []);
    }
    return widget.gateway.fetchLessonQuizAttempts(_module.id, _lesson.index);
  }

  /// The workbook rows taught by this lesson (for lessons generated from the
  /// workbook); empty for other lessons or when vocabulary is unavailable.
  Future<List<LocalVocabularyEntry>> _loadLessonWords() async {
    final gateway = widget.gateway;
    if (gateway is! DictionaryGateway) return const [];
    try {
      final catalog = await (gateway as DictionaryGateway).localVocabulary();
      return catalog.vocabulary
          .where(
            (entry) => isWorkbookLessonEntry(
              entry,
              moduleTitle: _module.title,
              lessonTitle: _lesson.title,
            ),
          )
          .toList();
    } on Exception {
      return const [];
    }
  }

  void _startQuiz() {
    setState(() {
      _answers = List.filled(_lesson.quiz.length, -1);
      _result = null;
      _showReview = false;
      _errorMessage = null;
      _view = _LessonView.quiz;
    });
  }

  Future<void> _playAudio() async {
    final audioUrl = _lesson.audioUrl;
    if (audioUrl == null) return;
    setState(() => _audioError = null);
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        final contentGateway = widget.gateway;
        if (contentGateway is DictionaryGateway) {
          final dictionaryGateway = contentGateway as DictionaryGateway;
          if (audioUrl.startsWith('/resources/')) {
            final bytes = await dictionaryGateway.fetchResourceBytes(audioUrl);
            await _audioPlayer.play(BytesSource(bytes));
          } else {
            await _audioPlayer.play(UrlSource(audioUrl));
          }
        } else {
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      }
    } on Exception {
      if (mounted) {
        setState(() => _audioError = 'Audio could not be played. Try again.');
      }
    }
  }

  Future<void> _completeLesson() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.gateway.completeModuleLesson(
        _module.id,
        _lesson.index,
      );
      if (!mounted) return;
      setState(() {
        _module = updated;
        _lesson = updated.lessons[_lesson.index];
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_answers.any((answer) => answer < 0)) {
      setState(() => _errorMessage = 'Select one answer for every question.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.gateway.submitLessonQuiz(
        _module.id,
        _lesson.index,
        _answers,
      );
      if (!mounted) return;
      setState(() {
        final wasCompleted = _lesson.completed;
        if (result.module case final updated?) {
          _module = updated;
          _lesson = updated.lessons[_lesson.index];
        } else {
          _lesson = _lesson.copyWith(completed: true);
          final lessons = [..._module.lessons]..[_lesson.index] = _lesson;
          _module = _module.copyWith(
            completedLessons: wasCompleted
                ? _module.completedLessons
                : _module.completedLessons + 1,
            lastLessonIndex: _lesson.index,
            lessons: lessons,
          );
        }
        _result = result;
        _showReview = false;
        _view = _LessonView.results;
        _quizHistory = _loadQuizHistory();
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openNextLesson() async {
    final nextIndex = _lesson.index + 1;
    if (nextIndex >= _module.lessonCount) {
      Navigator.of(context).pop(_module);
      return;
    }
    await _openLesson(nextIndex);
  }

  Future<void> _openPreviousLesson() => _openLesson(_lesson.index - 1);

  Future<void> _openLesson(int lessonIndex) async {
    if (lessonIndex < 0 || lessonIndex >= _module.lessonCount) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.gateway.startModuleLesson(
        _module.id,
        lessonIndex,
      );
      if (!mounted) return;
      setState(() {
        _module = updated;
        _lesson = updated.lessons[lessonIndex];
        _answers = [];
        _result = null;
        _showReview = false;
        _view = _LessonView.lesson;
        _quizHistory = _loadQuizHistory();
        _lessonWords = _loadLessonWords();
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPastResult(QuizResult result) {
    setState(() {
      _result = result;
      _showReview = true;
      _errorMessage = null;
      _view = _LessonView.results;
    });
  }

  void _goBack() {
    if (_view != _LessonView.lesson) {
      setState(() {
        _view = _LessonView.lesson;
        _result = null;
        _showReview = false;
        _errorMessage = null;
      });
      return;
    }
    Navigator.of(context).pop(_module);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_view) {
      _LessonView.lesson => _lesson.title,
      _LessonView.quiz => 'Quiz',
      _LessonView.results => 'Quiz Results',
    };
    // System Back behaves exactly like the app-bar arrow: from the quiz or
    // its results it returns to the lesson page; on the lesson page it
    // leaves and hands the updated module back so progress refreshes.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: _buildScaffold(title),
    );
  }

  Widget _buildScaffold(String title) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: _view == _LessonView.lesson ? 'Back to module' : 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        bottom: weaveAppBarBottom,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          AnimatedSwitcher(
            duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
                ? Duration.zero
                : const Duration(milliseconds: 240),
            child: KeyedSubtree(
              key: ValueKey(_view),
              child: switch (_view) {
                _LessonView.lesson => _buildLesson(),
                _LessonView.quiz => _buildQuiz(),
                _LessonView.results => _buildResults(),
              },
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.primary),
            ),
          ],
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x145A3A1A),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: _buildAction(),
        ),
      ),
    );
  }

  Widget _buildLesson() {
    final progress = _module.lessonCount == 0
        ? 0.0
        : (_lesson.index + 1) / _module.lessonCount;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: 'Lesson ${_lesson.index + 1} of ${_module.lessonCount}',
              icon: Icons.menu_book_rounded,
              tone: IconBadgeTone.dark,
            ),
            if (_lesson.completed)
              const StatusPill(
                label: 'Completed',
                icon: Icons.check_rounded,
                tone: IconBadgeTone.red,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _module.title,
          style: textTheme.labelLarge?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 10),
        LearnLiteProgressIndicator(progress: progress.clamp(0.0, 1.0)),
        const SizedBox(height: 22),
        if (_lesson.phrase != null ||
            _lesson.pronunciation != null ||
            _lesson.audioUrl != null)
          _buildPhraseCard(),
        if (_lesson.imageUrl != null) ...[
          _buildLessonImage(_lesson.imageUrl!),
          const SizedBox(height: 14),
        ],
        LearnLiteCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.notes_rounded, size: 34),
                  const SizedBox(width: 10),
                  Text('Lesson', style: textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              SelectableText(
                _lesson.content,
                style: textTheme.bodyLarge?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
        _buildLessonWords(),
        const SizedBox(height: 14),
        LearnLiteCard(
          backgroundColor: AppColors.lightPink,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learning coach', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Take your time with this lesson. Continue when you are ready.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_lesson.culturalNote != null) ...[
          const SizedBox(height: 14),
          LearnLiteCard(
            backgroundColor: AppColors.goldSoft,
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: AppColors.gold),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.diamond_outlined,
                                size: 18,
                                color: AppColors.goldDeep,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cultural note',
                                style: textTheme.titleSmall?.copyWith(
                                  color: AppColors.goldDeep,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lesson.culturalNote!,
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_lesson.keywords.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeader(title: 'Keywords'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final keyword in _lesson.keywords)
                Chip(
                  label: Text(keyword),
                  avatar: const Icon(
                    Icons.tag_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  backgroundColor: AppColors.white,
                ),
            ],
          ),
        ],
        if (_lesson.quiz.isNotEmpty) ...[
          const SizedBox(height: 22),
          LearnLiteCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(
                      icon: Icons.quiz_rounded,
                      tone: IconBadgeTone.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quiz', style: textTheme.titleMedium),
                          Text(
                            'A quiz is available for this lesson.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: '${_lesson.quiz.length} '
                          '${_lesson.quiz.length == 1 ? 'question' : 'questions'}',
                      tone: IconBadgeTone.gold,
                    ),
                  ],
                ),
                _buildQuizHistory(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLessonWords() => FutureBuilder<List<LocalVocabularyEntry>>(
    future: _lessonWords,
    builder: (context, snapshot) {
      final words = snapshot.data ?? const <LocalVocabularyEntry>[];
      if (words.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: 'Words in this lesson',
              subtitle:
                  '${words.length} workbook '
                  '${words.length == 1 ? 'entry' : 'entries'} · pending review',
            ),
            const SizedBox(height: 12),
            for (final word in words) ...[
              _WorkbookWordCard(entry: word),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildLessonImage(String imageUrl) {
    final contentGateway = widget.gateway;
    final isApiResource = imageUrl.startsWith('/resources/');
    final cachedFuture = contentGateway is DictionaryGateway && isApiResource
        ? (contentGateway as DictionaryGateway).fetchResourceBytes(imageUrl)
        : Future<Uint8List?>.value(null);
    return FutureBuilder<Uint8List?>(
      future: cachedFuture,
      builder: (context, snapshot) {
        Widget image;
        if (snapshot.data case final bytes?) {
          image = Image.memory(bytes, fit: BoxFit.cover);
        } else if (isApiResource && snapshot.hasError) {
          image = const Center(child: Icon(Icons.image_not_supported_outlined));
        } else if (isApiResource) {
          image = const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        } else {
          image = Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.image_not_supported_outlined)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 16 / 9, child: image),
        );
      },
    );
  }

  Widget _buildPhraseCard() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LearnLiteCard(
        backgroundColor: AppColors.charcoal,
        padding: EdgeInsets.zero,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phrase',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (_lesson.phrase != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      _lesson.phrase!,
                      style: textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                  if (_lesson.pronunciation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pronunciation: ${_lesson.pronunciation}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  if (_lesson.audioUrl != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _playAudio,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.darkBackground,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: Icon(
                        _playerState == PlayerState.playing
                            ? Icons.pause_rounded
                            : Icons.volume_up_rounded,
                      ),
                      label: Text(
                        _playerState == PlayerState.playing
                            ? 'Pause audio'
                            : 'Play pronunciation',
                      ),
                    ),
                    if (_audioError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _audioError!,
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const DecorativeBorder(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizHistory() {
    return FutureBuilder<List<QuizResult>>(
      future: _quizHistory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quiz history could not be loaded.'),
              TextButton(
                onPressed: () => setState(() {
                  _quizHistory = _loadQuizHistory();
                }),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        final attempts = snapshot.data ?? const [];
        if (attempts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Previous attempts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            for (final attempt in attempts.reversed.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(
                  icon: Icons.history_rounded,
                  tone: IconBadgeTone.cream,
                  size: 38,
                ),
                title: Text(
                  '${attempt.correctAnswers} of ${attempt.totalQuestions} correct',
                ),
                subtitle: Text(
                  'Completed ${friendlyDateTime(attempt.completedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPastResult(attempt),
              ),
          ],
        );
      },
    );
  }

  Widget _buildQuiz() {
    final answeredQuestions = _answers.where((answer) => answer >= 0).length;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IconBadge(icon: Icons.quiz_rounded, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_lesson.title, style: textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: LearnLiteProgressIndicator(
                progress: _lesson.quiz.isEmpty
                    ? 0
                    : answeredQuestions / _lesson.quiz.length,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$answeredQuestions of ${_lesson.quiz.length} answered',
              style: textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LearnLiteCard(
          backgroundColor: AppColors.goldSoft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.goldDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Earn 1 XP per correct answer when you improve your best score.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var index = 0; index < _lesson.quiz.length; index++) ...[
          const SizedBox(height: 14),
          _buildQuestion(index, _lesson.quiz[index]),
        ],
      ],
    );
  }

  Widget _buildQuestion(int questionIndex, QuizQuestion question) {
    return LearnLiteCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${questionIndex + 1} of ${_lesson.quiz.length}',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          for (
            var answerIndex = 0;
            answerIndex < question.choices.length;
            answerIndex++
          )
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnswerOptionTile(
                index: answerIndex,
                label: question.choices[answerIndex],
                state: _answers[questionIndex] == answerIndex
                    ? AnswerOptionState.selected
                    : AnswerOptionState.idle,
                onTap: _isSaving
                    ? null
                    : () => setState(() {
                        _answers[questionIndex] = answerIndex;
                        _errorMessage = null;
                      }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final result = _result!;
    final leveledUp =
        result.previousLevel != null &&
        result.currentLevel != null &&
        result.currentLevel! > result.previousLevel!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnLiteCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DecorativeBorder(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  children: [
                    Text(
                      _showReview ? 'Quiz review' : 'Quiz complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 18),
                    ScoreRing(
                      progress: result.totalQuestions == 0
                          ? 0
                          : result.correctAnswers / result.totalQuestions,
                      // `score` is a percentage in local results, so the
                      // headline uses the correct-answer count instead.
                      center: Text(
                        '${result.correctAnswers} / ${result.totalQuestions}',
                        key: const ValueKey('quiz-result-score'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result.totalQuestions == 0
                          ? 'correct answers'
                          : 'correct answers · '
                                '${(100 * result.correctAnswers / result.totalQuestions).round()}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultCount(
                            label: 'Correct',
                            count: result.correctAnswers,
                            color: AppColors.success,
                            background: AppColors.successSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResultCount(
                            label: 'Incorrect',
                            count: result.incorrectAnswers,
                            color: AppColors.primary,
                            background: AppColors.lightPink,
                          ),
                        ),
                      ],
                    ),
                    if (result.xpAwarded != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '+${result.totalXpAwarded} XP',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: AppColors.goldDeep),
                            ),
                            const SizedBox(height: 2),
                            Text('Quiz XP: +${result.xpAwarded}'),
                            if (result.lessonXpAwarded > 0)
                              Text(
                                'Lesson completion XP: +${result.lessonXpAwarded}',
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (leveledUp) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.charcoal,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Level up! You reached Level ${result.currentLevel}.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.gold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_showReview) ...[
          const SizedBox(height: 20),
          Text('Review answers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var index = 0; index < result.questions.length; index++)
            _buildReviewedAnswer(index, result.questions[index]),
        ],
      ],
    );
  }

  Widget _buildReviewedAnswer(int index, QuizResultQuestion question) {
    final isCorrect =
        question.selectedAnswerIndex == question.correctAnswerIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LearnLiteCard(
        padding: const EdgeInsets.all(16),
        borderColor: (isCorrect ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 20,
                  color: isCorrect ? AppColors.success : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Question ${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question.question,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${isCorrect ? 'Your answer' : 'Correct answer'}: '
              '${question.choices[question.correctAnswerIndex]}',
              style: const TextStyle(color: AppColors.primary),
            ),
            if (!isCorrect)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Your answer: ${question.choices[question.selectedAnswerIndex]}',
                  style: const TextStyle(color: AppColors.gray),
                ),
              ),
            if (question.explanation != null) ...[
              const SizedBox(height: 8),
              Text(question.explanation!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (_view == _LessonView.quiz) {
      return FilledButton(
        onPressed: _isSaving ? null : _submitQuiz,
        child: _isSaving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Check Answer'),
      );
    }
    if (_view == _LessonView.results) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _showReview = !_showReview),
            child: Text(_showReview ? 'Hide Answers' : 'Review Answers'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isSaving ? null : _openNextLesson,
            child: Text(
              _lesson.index + 1 < _module.lessonCount
                  ? 'Next Lesson'
                  : 'Back to Module',
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lesson.quiz.isNotEmpty)
          FilledButton(
            onPressed: _isSaving ? null : _startQuiz,
            child: Text(_lesson.completed ? 'Retake Quiz' : 'Start Quiz'),
          )
        else if (!_lesson.completed)
          FilledButton(
            onPressed: _isSaving ? null : _completeLesson,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Complete Lesson'),
          )
        else
          const Text(
            'Lesson completed',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.primary),
          ),
        if (_lesson.index > 0 || _lesson.index + 1 < _module.lessonCount) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_lesson.index > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _openPreviousLesson,
                    child: const Text('Previous Lesson'),
                  ),
                ),
              if (_lesson.index > 0 && _lesson.index + 1 < _module.lessonCount)
                const SizedBox(width: 8),
              if (_lesson.index + 1 < _module.lessonCount)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _openNextLesson,
                    child: const Text('Next Lesson'),
                  ),
                ),
            ],
          ),
        ],
        if (_lesson.completed && _lesson.index + 1 == _module.lessonCount) ...[
          const SizedBox(height: 8),
          _buildNextLessonButton(),
        ],
      ],
    );
  }

  Widget _buildNextLessonButton() => OutlinedButton(
    onPressed: _isSaving ? null : _openNextLesson,
    child: Text(
      _lesson.index + 1 < _module.lessonCount
          ? 'Next Lesson'
          : 'Back to Module',
    ),
  );
}

/// One workbook row: Subanen form, English and Cebuano/Bisaya meanings, the
/// dialect and notes as recorded, the review status and the source row.
class _WorkbookWordCard extends StatelessWidget {
  const _WorkbookWordCard({required this.entry});

  final LocalVocabularyEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final review = entry.reviewStatus.trim().isEmpty
        ? 'Pending review'
        : entry.reviewStatus.trim();
    final variety = entry.variety.trim();
    return LearnLiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.subanen.trim().isEmpty
                      ? 'Subanen form not recorded'
                      : entry.subanen,
                  style: textTheme.titleLarge?.copyWith(
                    color: entry.subanen.trim().isEmpty
                        ? AppColors.gray
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: review, tone: IconBadgeTone.gold),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry.english, style: textTheme.titleSmall),
          if (entry.bisaya.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Cebuano/Bisaya: ${entry.bisaya}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          if (variety.isNotEmpty && variety.toLowerCase() != 'not stated') ...[
            const SizedBox(height: 2),
            Text(
              'Dialect: $variety',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          if (entry.alternateForms.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Other forms: ${entry.alternateForms}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          if (entry.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.notes, style: textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _WordMeta(
                icon: Icons.volume_off_outlined,
                text: 'No recorded audio in the workbook',
              ),
              _WordMeta(
                icon: Icons.description_outlined,
                text: 'Workbook row ${entry.sourceRow}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WordMeta extends StatelessWidget {
  const _WordMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.gray),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.gray),
        ),
      ),
    ],
  );
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({
    required this.label,
    required this.count,
    required this.color,
    required this.background,
  });

  final String label;
  final int count;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
