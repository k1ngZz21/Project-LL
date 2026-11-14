import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import 'content_gateway.dart';
import 'local_vocabulary.dart';

enum _PracticeMode { flashcards, quiz }

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({required this.gateway, super.key});

  final DictionaryGateway gateway;

  @override
  State<VocabularyPracticeScreen> createState() =>
      _VocabularyPracticeScreenState();
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  static const _sources = [
    'All',
    'LearnLite vocabulary',
    'Starter list',
    'Still needed',
  ];

  late Future<LocalVocabularyCatalog> _catalogFuture;
  _PracticeMode _mode = _PracticeMode.flashcards;
  String _source = 'All';
  int _cardIndex = 0;
  bool _showSubanen = false;
  bool _isSaving = false;
  bool _quizStarted = false;
  bool _quizFinished = false;
  bool _answerChecked = false;
  int _quizIndex = 0;
  int _selectedAnswer = -1;
  int _correctAnswers = 0;
  List<LocalVocabularyEntry> _quizEntries = const [];
  List<String> _choices = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.gateway.localVocabulary();
  }

  List<LocalVocabularyEntry> _entries(
    LocalVocabularyCatalog catalog, {
    String? source,
  }) {
    final unique = <String, LocalVocabularyEntry>{};
    for (final entry in catalog.search('', source: source ?? _source)) {
      if (entry.english.trim().isEmpty || entry.subanen.trim().isEmpty) {
        continue;
      }
      unique.putIfAbsent(entry.subanen.trim().toLowerCase(), () => entry);
    }
    return unique.values.toList();
  }

  void _selectSource(String source) {
    setState(() {
      _source = source;
      _cardIndex = 0;
      _showSubanen = false;
      _quizStarted = false;
      _quizFinished = false;
      _errorMessage = null;
    });
  }

  void _startQuiz(List<LocalVocabularyEntry> entries) {
    final questions = [...entries]..shuffle(Random());
    setState(() {
      _mode = _PracticeMode.quiz;
      _quizEntries = questions.take(5).toList();
      _quizStarted = true;
      _quizFinished = _quizEntries.isEmpty;
      _quizIndex = 0;
      _selectedAnswer = -1;
      _correctAnswers = 0;
      _answerChecked = false;
      _errorMessage = null;
      _choices = _quizEntries.isEmpty
          ? const []
          : _choicesFor(_quizEntries.first, entries);
    });
  }

  List<String> _choicesFor(
    LocalVocabularyEntry question,
    List<LocalVocabularyEntry> entries,
  ) {
    final options = <String, String>{
      question.subanen.trim().toLowerCase(): question.subanen.trim(),
    };
    final candidates = [...entries]..shuffle(Random());
    for (final candidate in candidates) {
      final word = candidate.subanen.trim();
      if (word.isEmpty) continue;
      options.putIfAbsent(word.toLowerCase(), () => word);
      if (options.length == 4) break;
    }
    final result = options.values.toList()..shuffle(Random());
    return result;
  }

  Future<void> _checkAnswer(LocalVocabularyEntry question) async {
    if (_selectedAnswer < 0 || _answerChecked || _isSaving) {
      if (_selectedAnswer < 0) {
        setState(() => _errorMessage = 'Choose an answer first.');
      }
      return;
    }
    final isCorrect =
        _choices[_selectedAnswer].toLowerCase() ==
        question.subanen.trim().toLowerCase();
    if (isCorrect && question.id != null) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      try {
        await widget.gateway.setVocabularyLearningStatus(
          vocabularyId: question.id!,
          learned: true,
          bookmarked: question.isBookmarked,
        );
        if (!mounted) return;
        setState(() {
          _catalogFuture = widget.gateway.localVocabulary();
        });
      } on AuthFailure catch (error) {
        if (mounted) setState(() => _errorMessage = error.message);
        return;
      } on DatabaseException {
        if (mounted) {
          setState(
            () => _errorMessage = 'Could not save your vocabulary progress.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
    if (mounted) {
      setState(() {
        _answerChecked = true;
        if (isCorrect) _correctAnswers++;
        _errorMessage = null;
      });
    }
  }

  void _nextQuestion(List<LocalVocabularyEntry> entries) {
    if (_quizIndex + 1 >= _quizEntries.length) {
      setState(() => _quizFinished = true);
      return;
    }
    final nextIndex = _quizIndex + 1;
    setState(() {
      _quizIndex = nextIndex;
      _selectedAnswer = -1;
      _answerChecked = false;
      _errorMessage = null;
      _choices = _choicesFor(_quizEntries[nextIndex], entries);
    });
  }

  Future<void> _setVocabularyStatus(
    LocalVocabularyEntry entry, {
    bool? learned,
    bool? bookmarked,
  }) async {
    final id = entry.id;
    if (id == null || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.setVocabularyLearningStatus(
        vocabularyId: id,
        learned: learned ?? entry.isLearned,
        bookmarked: bookmarked ?? entry.isBookmarked,
      );
      if (mounted) {
        setState(() {
          _catalogFuture = widget.gateway.localVocabulary();
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on DatabaseException {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not save your vocabulary progress.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vocabulary Practice')),
    body: FutureBuilder<LocalVocabularyCatalog>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Vocabulary could not be loaded',
            message: snapshot.error.toString(),
          );
        }
        final entries = _entries(snapshot.data!);
        final currentCard = entries.isEmpty
            ? null
            : entries[_cardIndex % entries.length];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Practice from your workbooks'),
                    const SizedBox(height: 8),
                    Text(
                      'Cards and quiz answers come from the bundled vocabulary '
                      'records. Source and review labels are shown; a workbook '
                      'entry is not automatically a verified translation.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.gray),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final source in _sources)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(source),
                                selected: _source == source,
                                onSelected: (_) => _selectSource(source),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_PracticeMode>(
                      segments: const [
                        ButtonSegment(
                          value: _PracticeMode.flashcards,
                          icon: Icon(Icons.flip_to_front_outlined),
                          label: Text('Flashcards'),
                        ),
                        ButtonSegment(
                          value: _PracticeMode.quiz,
                          icon: Icon(Icons.quiz_outlined),
                          label: Text('Quiz'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (selection) {
                        if (selection.single == _PracticeMode.flashcards) {
                          setState(() {
                            _mode = _PracticeMode.flashcards;
                            _showSubanen = false;
                            _errorMessage = null;
                          });
                        } else {
                          _startQuiz(entries);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (entries.isEmpty)
                      const EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No complete word pairs in this source',
                        message:
                            'Choose another source or browse the workbook list. '
                            'Entries without both English and Subanen forms are '
                            'not used as quiz answers.',
                      )
                    else if (_mode == _PracticeMode.flashcards)
                      _buildFlashcard(currentCard!, entries.length)
                    else
                      _buildQuiz(entries),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _buildFlashcard(LocalVocabularyEntry entry, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${_cardIndex + 1} of $count',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      const SizedBox(height: 8),
      Semantics(
        button: true,
        label: _showSubanen
            ? 'Show the English meaning'
            : 'Reveal the Subanen form',
        child: InkWell(
          key: const ValueKey('practice-flashcard'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _showSubanen = !_showSubanen),
          child: LearnLiteCard(
            backgroundColor: _showSubanen
                ? AppColors.darkBackground
                : AppColors.white,
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            child: Column(
              children: [
                Text(
                  _showSubanen ? 'Subanen form' : 'English meaning',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _showSubanen ? AppColors.gold : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _showSubanen ? entry.subanen : entry.english,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _showSubanen ? AppColors.white : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _showSubanen
                      ? 'Tap to see the English meaning'
                      : 'Tap to reveal',
                  style: TextStyle(
                    color: _showSubanen ? AppColors.white : AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SourceLabel(entry: entry),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('practice-mark-learned'),
              onPressed: _isSaving
                  ? null
                  : () =>
                        _setVocabularyStatus(entry, learned: !entry.isLearned),
              icon: Icon(
                entry.isLearned
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
              ),
              label: Text(entry.isLearned ? 'Learned' : 'Mark learned'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('practice-bookmark'),
            tooltip: entry.isBookmarked ? 'Remove bookmark' : 'Bookmark word',
            onPressed: _isSaving
                ? null
                : () => _setVocabularyStatus(
                    entry,
                    bookmarked: !entry.isBookmarked,
                  ),
            icon: Icon(
              entry.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _cardIndex = (_cardIndex - 1 + count) % count;
                _showSubanen = false;
              }),
              child: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => setState(() {
                _cardIndex = (_cardIndex + 1) % count;
                _showSubanen = false;
              }),
              child: const Text('Next card'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildQuiz(List<LocalVocabularyEntry> entries) {
    if (!_quizStarted) {
      return Center(
        child: FilledButton(
          onPressed: () => _startQuiz(entries),
          child: const Text('Start vocabulary quiz'),
        ),
      );
    }
    if (_quizFinished) {
      return LearnLiteCard(
        backgroundColor: AppColors.creamSecondary,
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.primary,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'Practice complete',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text('$_correctAnswers of ${_quizEntries.length} correct'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _startQuiz(entries),
              child: const Text('Try another set'),
            ),
          ],
        ),
      );
    }

    final question = _quizEntries[_quizIndex];
    final selectedIsCorrect =
        _selectedAnswer >= 0 &&
        _choices[_selectedAnswer].toLowerCase() ==
            question.subanen.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${_quizIndex + 1} of ${_quizEntries.length}',
              ),
            ),
            Text('$_correctAnswers correct'),
          ],
        ),
        const SizedBox(height: 10),
        LearnLiteCard(
          backgroundColor: AppColors.lightPink,
          child: Column(
            children: [
              const Text('Choose the Subanen form for'),
              const SizedBox(height: 8),
              Text(
                question.english,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (var index = 0; index < _choices.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: ValueKey('practice-choice-$index'),
              onPressed: _answerChecked || _isSaving
                  ? null
                  : () => setState(() {
                      _selectedAnswer = index;
                      _errorMessage = null;
                    }),
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    _answerChecked &&
                        _choices[index].toLowerCase() ==
                            question.subanen.trim().toLowerCase()
                    ? const Color(0xFFD6F5DF)
                    : _answerChecked && index == _selectedAnswer
                    ? AppColors.lightPink
                    : AppColors.white,
              ),
              child: Text(_choices[index]),
            ),
          ),
        const SizedBox(height: 12),
        if (_answerChecked)
          Text(
            selectedIsCorrect
                ? 'Correct. Your workbook record is marked as learned.'
                : 'Not quite. The source-list answer is ${question.subanen}.',
            style: TextStyle(
              color: selectedIsCorrect
                  ? const Color(0xFF287A45)
                  : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 8),
        _SourceLabel(entry: question),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('practice-check-answer'),
          onPressed: _isSaving
              ? null
              : _answerChecked
              ? () => _nextQuestion(entries)
              : () => _checkAnswer(question),
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _answerChecked
                      ? _quizIndex + 1 == _quizEntries.length
                            ? 'See results'
                            : 'Next question'
                      : 'Check answer',
                ),
        ),
      ],
    );
  }
}

class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.entry});

  final LocalVocabularyEntry entry;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    backgroundColor: AppColors.cream,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.reviewStatus, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 3),
        Text(
          '${entry.sourceFile} · row ${entry.sourceRow}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.gray),
        ),
      ],
    ),
  );
}
