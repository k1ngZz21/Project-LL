import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/learnlite_card.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';

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
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.gateway.startModuleLesson(
        _module.id,
        nextIndex,
      );
      if (!mounted) return;
      setState(() {
        _module = updated;
        _lesson = updated.lessons[nextIndex];
        _answers = [];
        _result = null;
        _showReview = false;
        _view = _LessonView.lesson;
        _quizHistory = _loadQuizHistory();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: _view == _LessonView.lesson ? 'Back to module' : 'Back',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        children: [
          if (_view == _LessonView.lesson) _buildLesson(),
          if (_view == _LessonView.quiz) _buildQuiz(),
          if (_view == _LessonView.results) _buildResults(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.primary),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: _buildAction(),
      ),
    );
  }

  Widget _buildLesson() {
    final progress = _module.lessonCount == 0
        ? 0.0
        : (_lesson.index + 1) / _module.lessonCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _module.title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.gray),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Lesson ${_lesson.index + 1} of ${_module.lessonCount}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (_lesson.completed)
              const Text(
                'Completed',
                style: TextStyle(color: AppColors.primary),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          color: AppColors.primary,
          backgroundColor: AppColors.lightPink,
        ),
        const SizedBox(height: 20),
        if (_lesson.phrase != null ||
            _lesson.pronunciation != null ||
            _lesson.audioUrl != null)
          _buildPhraseCard(),
        if (_lesson.imageUrl != null) ...[
          const SizedBox(height: 14),
          _buildLessonImage(_lesson.imageUrl!),
        ],
        LearnLiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lesson', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SelectableText(
                _lesson.content,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LearnLiteCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.lightPink,
                foregroundColor: AppColors.primary,
                child: Icon(Icons.face_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning coach',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Take your time with this lesson. Continue when you are ready.',
                      style: Theme.of(context).textTheme.bodyMedium,
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
            backgroundColor: AppColors.cream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cultural note',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(_lesson.culturalNote!),
              ],
            ),
          ),
        ],
        if (_lesson.keywords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Keywords', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final keyword in _lesson.keywords)
                Chip(
                  label: Text(keyword),
                  backgroundColor: AppColors.lightPink,
                  side: BorderSide.none,
                ),
            ],
          ),
        ],
        if (_lesson.quiz.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Quiz', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A quiz is available for this lesson.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: 12),
          _buildQuizHistory(),
        ],
      ],
    );
  }

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LearnLiteCard(
        backgroundColor: AppColors.lightPink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phrase', style: Theme.of(context).textTheme.titleSmall),
            if (_lesson.phrase != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _lesson.phrase!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
            if (_lesson.pronunciation != null) ...[
              const SizedBox(height: 8),
              Text('Pronunciation: ${_lesson.pronunciation}'),
            ],
            if (_lesson.audioUrl != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _playAudio,
                icon: Icon(
                  _playerState == PlayerState.playing
                      ? Icons.pause
                      : Icons.volume_up_outlined,
                ),
                label: Text(
                  _playerState == PlayerState.playing
                      ? 'Pause audio'
                      : 'Play pronunciation',
                ),
              ),
              if (_audioError != null)
                Text(
                  _audioError!,
                  style: const TextStyle(color: AppColors.primary),
                ),
            ],
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
            Text(
              'Previous attempts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final attempt in attempts.reversed.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, color: AppColors.primary),
                title: Text(
                  '${attempt.correctAnswers} of ${attempt.totalQuestions} correct',
                ),
                subtitle: Text(
                  'Completed ${attempt.completedAt.toLocal()}',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.lightPink,
              foregroundColor: AppColors.primary,
              child: Icon(Icons.face_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _lesson.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: answeredQuestions / _lesson.quiz.length,
          color: AppColors.primary,
          backgroundColor: AppColors.lightPink,
        ),
        const SizedBox(height: 8),
        Text(
          '$answeredQuestions of ${_lesson.quiz.length} answered',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.gray),
        ),
        const SizedBox(height: 12),
        LearnLiteCard(
          backgroundColor: AppColors.cream,
          child: Row(
            children: [
              const Icon(Icons.stars_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Earn 1 XP per correct answer when you improve your best score.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: RadioGroup<int>(
              groupValue: _answers[questionIndex] < 0
                  ? null
                  : _answers[questionIndex],
              onChanged: (value) {
                if (value == null || _isSaving) return;
                setState(() {
                  _answers[questionIndex] = value;
                  _errorMessage = null;
                });
              },
              child: Column(
                children: [
                  for (
                    var answerIndex = 0;
                    answerIndex < question.choices.length;
                    answerIndex++
                  )
                    RadioListTile<int>(
                      value: answerIndex,
                      title: Text(question.choices[answerIndex]),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
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
          backgroundColor: AppColors.cream,
          child: Column(
            children: [
              const Icon(
                Icons.celebration_outlined,
                size: 44,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                _showReview ? 'Quiz review' : 'Quiz complete',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${result.score} / ${result.totalQuestions}',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: AppColors.primary),
              ),
              const Text('correct answers'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ResultCount(
                    label: 'Correct',
                    count: result.correctAnswers,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 24),
                  _ResultCount(
                    label: 'Incorrect',
                    count: result.incorrectAnswers,
                    color: AppColors.gray,
                  ),
                ],
              ),
              if (result.xpAwarded != null) ...[
                const SizedBox(height: 14),
                Text(
                  '+${result.totalXpAwarded} XP',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppColors.primary),
                ),
                Text('Quiz XP: +${result.xpAwarded}'),
                if (result.lessonXpAwarded > 0)
                  Text('Lesson completion XP: +${result.lessonXpAwarded}'),
              ],
              if (leveledUp) ...[
                const SizedBox(height: 12),
                Text(
                  'Level up! You reached Level ${result.currentLevel}.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        LearnLiteCard(
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.gray),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Outfit rewards are unavailable until approved customization items are added.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1}',
              style: Theme.of(context).textTheme.labelLarge,
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
    if (_lesson.quiz.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _isSaving ? null : _startQuiz,
            child: Text(_lesson.completed ? 'Retake Quiz' : 'Start Quiz'),
          ),
          if (_lesson.completed) ...[
            const SizedBox(height: 8),
            _buildNextLessonButton(),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_lesson.completed)
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
        if (_lesson.completed) ...[
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

class _ResultCount extends StatelessWidget {
  const _ResultCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
