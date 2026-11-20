import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/app_colors.dart';
import '../../core/display_format.dart';
import '../../core/user_message.dart';
import '../../core/workbook_modules.dart';
import '../../widgets/answer_option_tile.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_progress_indicator.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import 'content_gateway.dart';
import 'local_vocabulary.dart';

enum _PracticeMode { flashcards, quiz }

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({
    required this.gateway,
    this.startInQuiz = false,
    this.showAppBar = true,
    super.key,
  });

  final DictionaryGateway gateway;
  final bool startInQuiz;
  final bool showAppBar;

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
  late Future<List<VocabularyQuizAttempt>> _quizHistoryFuture;
  late _PracticeMode _mode;
  static const _allModules = 'All modules';

  String _source = 'All';
  String _module = _allModules;
  String _category = 'All categories';

  /// Identification mode: see the Subanen form, choose the English meaning.
  /// Off: see the English meaning, choose the Subanen form.
  bool _identify = false;
  int _cardIndex = 0;
  bool _showSubanen = false;
  bool _isSaving = false;
  bool _quizStarted = false;
  bool _quizFinished = false;
  bool _answerChecked = false;
  int _quizIndex = 0;
  int _selectedAnswer = -1;
  int _correctAnswers = 0;
  bool _attemptSaved = false;
  List<LocalVocabularyEntry> _quizEntries = const [];
  List<String> _choices = const [];
  List<VocabularyQuizResponse> _quizResponses = [];
  String? _errorMessage;
  int get _quizScore => _quizResponses.isEmpty
      ? 0
      : (100 * _correctAnswers / _quizResponses.length).round();

  @override
  void initState() {
    super.initState();
    _mode = widget.startInQuiz ? _PracticeMode.quiz : _PracticeMode.flashcards;
    _catalogFuture = widget.gateway.localVocabulary();
    _quizHistoryFuture = widget.gateway.fetchVocabularyQuizAttempts();
  }

  List<LocalVocabularyEntry> _entries(
    LocalVocabularyCatalog catalog, {
    String? source,
  }) {
    final unique = <String, LocalVocabularyEntry>{};
    for (final entry in catalog.search(
      '',
      source: source ?? _source,
      category: _category,
    )) {
      if (entry.english.trim().isEmpty || entry.subanen.trim().isEmpty) {
        continue;
      }
      if (_module != _allModules &&
          workbookModuleName(entry.module) != _module) {
        continue;
      }
      unique.putIfAbsent(entry.subanen.trim().toLowerCase(), () => entry);
    }
    return unique.values.toList();
  }

  /// Modules present in the vocabulary, numbered workbook modules first.
  List<String> _modules(LocalVocabularyCatalog catalog) {
    final numbered = <int, String>{};
    final others = <String>{};
    for (final entry in [
      ...catalog.vocabulary,
      ...catalog.starterList,
      ...catalog.stillNeeded,
    ]) {
      final name = workbookModuleName(entry.module);
      if (name.isEmpty) continue;
      final number = workbookModuleNumber(entry.module);
      if (number != null) {
        numbered.putIfAbsent(number, () => name);
      } else {
        others.add(name);
      }
    }
    final ordered = numbered.keys.toList()..sort();
    final numberedNames = [for (final n in ordered) numbered[n]!];
    return [
      ...numberedNames,
      ...(others.difference(numberedNames.toSet()).toList()..sort()),
    ];
  }

  /// Categories inside the selected module (all categories when none is).
  List<String> _categories(LocalVocabularyCatalog catalog) {
    if (_module == _allModules) return catalog.categories;
    return {
      for (final entry in [
        ...catalog.vocabulary,
        ...catalog.starterList,
        ...catalog.stillNeeded,
      ])
        if (workbookModuleName(entry.module) == _module &&
            entry.category.isNotEmpty)
          entry.category,
    }.toList()..sort();
  }

  void _selectModule(String module) {
    setState(() {
      _module = module;
      _category = 'All categories';
      _cardIndex = 0;
      _showSubanen = false;
      _quizStarted = false;
      _quizFinished = false;
      _quizResponses = [];
      _errorMessage = null;
    });
  }

  String _prompt(LocalVocabularyEntry entry) =>
      (_identify ? entry.subanen : entry.english).trim();

  String _answer(LocalVocabularyEntry entry) =>
      (_identify ? entry.english : entry.subanen).trim();

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

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _cardIndex = 0;
      _showSubanen = false;
      _quizStarted = false;
      _quizFinished = false;
      _quizResponses = [];
      _errorMessage = null;
    });
  }

  void _startQuiz(List<LocalVocabularyEntry> entries) {
    if (entries.length < 2) {
      setState(() {
        _mode = _PracticeMode.quiz;
        _quizStarted = false;
        _quizFinished = false;
        _errorMessage =
            'At least two distinct Subanen word pairs are needed for a quiz.';
      });
      return;
    }
    final questions = [...entries]..shuffle(Random());
    setState(() {
      _mode = _PracticeMode.quiz;
      _quizEntries = questions.take(5).toList();
      _quizStarted = true;
      _quizFinished = _quizEntries.isEmpty;
      _quizIndex = 0;
      _selectedAnswer = -1;
      _correctAnswers = 0;
      _attemptSaved = false;
      _quizResponses = [];
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
      _answer(question).toLowerCase(): _answer(question),
    };
    final candidates = [...entries]..shuffle(Random());
    for (final candidate in candidates) {
      final word = _answer(candidate);
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
        _answer(question).toLowerCase();
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
        _quizResponses.add(
          // `english` holds the prompt shown: the English meaning, or the
          // Subanen form in identification mode.
          VocabularyQuizResponse(
            english: _prompt(question),
            selectedAnswer: _choices[_selectedAnswer],
            correctAnswer: _answer(question),
          ),
        );
        _errorMessage = null;
      });
    }
  }

  Future<void> _nextQuestion(List<LocalVocabularyEntry> entries) async {
    if (_quizIndex + 1 >= _quizEntries.length) {
      setState(() => _quizFinished = true);
      await _saveQuizAttempt();
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

  Future<void> _saveQuizAttempt() async {
    if (_attemptSaved || _isSaving || _quizResponses.isEmpty) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.saveVocabularyQuizAttempt(
        category: _category,
        responses: List.unmodifiable(_quizResponses),
      );
      if (mounted) {
        setState(() {
          _attemptSaved = true;
          _quizHistoryFuture = widget.gateway.fetchVocabularyQuizAttempts();
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on DatabaseException {
      if (mounted) {
        setState(() => _errorMessage = 'Could not save your quiz result.');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    appBar: widget.showAppBar
        ? AppBar(title: const Text('Vocabulary Practice'))
        : null,
    body: FutureBuilder<LocalVocabularyCatalog>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        // Keep showing the current cards while a refresh (after marking a
        // word learned) is in flight, so the page does not jump to the top.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Vocabulary could not be loaded',
            message: userMessage(
              snapshot.error,
              fallback:
                  'The vocabulary on this device could not be opened. Restart LearnLite and try again.',
            ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.gray,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cards and quiz answers come from the bundled vocabulary '
                            'records. Source and review labels are shown; a workbook '
                            'entry is not automatically a verified translation.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ),
                      ],
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
                    DropdownButtonFormField<String>(
                      key: const ValueKey('practice-module-filter'),
                      initialValue: _module,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      decoration: const InputDecoration(
                        labelText: 'Module',
                        prefixIcon: Icon(Icons.auto_stories_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allModules,
                          child: Text(_allModules),
                        ),
                        for (final module in _modules(snapshot.data!))
                          DropdownMenuItem(
                            value: module,
                            child: Text(
                              module,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _selectModule(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Re-created when the module changes, so the selection
                    // resets to "All categories".
                    KeyedSubtree(
                      key: ValueKey('category-for-$_module'),
                      child: DropdownButtonFormField<String>(
                      key: const ValueKey('practice-category-filter'),
                      initialValue: _category,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'All categories',
                          child: Text('All categories'),
                        ),
                        for (final category in _categories(snapshot.data!))
                          DropdownMenuItem(
                            value: category,
                            child: Text(
                              category,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) _selectCategory(value);
                      },
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
                    if (_mode == _PracticeMode.quiz) ...[
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        key: const ValueKey('practice-direction'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('English → Subanen'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Subanen → English'),
                          ),
                        ],
                        selected: {_identify},
                        onSelectionChanged: (selection) {
                          _identify = selection.single;
                          _startQuiz(entries);
                        },
                      ),
                    ],
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
                    if (_mode == _PracticeMode.quiz) ...[
                      const SizedBox(height: 24),
                      _buildQuizHistory(),
                    ],
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
      Row(
        children: [
          Expanded(
            child: LearnLiteProgressIndicator(
              progress: count == 0 ? 0 : (_cardIndex + 1) / count,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_cardIndex + 1} of $count',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
      const SizedBox(height: 14),
      Semantics(
        button: true,
        label: _showSubanen
            ? 'Show the English meaning'
            : 'Reveal the Subanen form',
        child: Pressable(
          child: InkWell(
            key: const ValueKey('practice-flashcard'),
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _showSubanen = !_showSubanen),
            child: _FlipFlashcard(
              showBack: _showSubanen,
              front: _FlashcardFace(
                label: 'English meaning',
                word: entry.english,
                hint: 'Tap to reveal',
                dark: false,
              ),
              back: _FlashcardFace(
                label: 'Subanen form',
                word: entry.subanen,
                hint: 'Tap to see the English meaning',
                dark: true,
              ),
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
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _cardIndex = (_cardIndex - 1 + count) % count;
                _showSubanen = false;
              }),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => setState(() {
                _cardIndex = (_cardIndex + 1) % count;
                _showSubanen = false;
              }),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Next card'),
            ),
          ),
        ],
      ),
    ],
  );

  AnswerOptionState _optionState(int index, LocalVocabularyEntry question) {
    final isAnswer =
        _choices[index].toLowerCase() == _answer(question).toLowerCase();
    if (_answerChecked) {
      if (isAnswer) return AnswerOptionState.correct;
      if (index == _selectedAnswer) return AnswerOptionState.incorrect;
      return AnswerOptionState.disabled;
    }
    return index == _selectedAnswer
        ? AnswerOptionState.selected
        : AnswerOptionState.idle;
  }

  Widget _buildQuiz(List<LocalVocabularyEntry> entries) {
    if (!_quizStarted) {
      return Center(
        child: entries.length < 2
            ? const EmptyState(
                icon: Icons.quiz_outlined,
                title: 'More vocabulary is needed',
                message: 'At least two distinct Subanen word pairs are needed for a multiple-choice quiz.',
              )
            : FilledButton(
                onPressed: () => _startQuiz(entries),
                child: const Text('Start vocabulary quiz'),
              ),
      );
    }
    if (_quizFinished) {
      return LearnLiteCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Text(
              'Practice complete',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ScoreRing(
              progress: _quizEntries.isEmpty
                  ? 0
                  : _correctAnswers / _quizEntries.length,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 26,
                  ),
                  Text(
                    '$_quizScore%',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctAnswers of ${_quizEntries.length} correct',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_quizEntries.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Score: $_quizScore%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 10),
              StatusPill(
                label: _attemptSaved
                    ? 'Result saved to your quiz history.'
                    : 'Your result has not been saved yet.',
                icon: _attemptSaved
                    ? Icons.cloud_done_outlined
                    : Icons.hourglass_empty_rounded,
                tone: _attemptSaved ? IconBadgeTone.gold : IconBadgeTone.cream,
              ),
              if (!_attemptSaved) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _isSaving ? null : _saveQuizAttempt,
                  child: Text(_isSaving ? 'Saving…' : 'Save result'),
                ),
              ],
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startQuiz(entries),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try another set'),
              ),
            ),
          ],
        ),
      );
    }

    final question = _quizEntries[_quizIndex];
    final selectedIsCorrect =
        _selectedAnswer >= 0 &&
        _choices[_selectedAnswer].toLowerCase() ==
            _answer(question).toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${_quizIndex + 1} of ${_quizEntries.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            StatusPill(
              label: '$_correctAnswers correct',
              icon: Icons.check_rounded,
              tone: IconBadgeTone.gold,
            ),
          ],
        ),
        const SizedBox(height: 10),
        LearnLiteProgressIndicator(
          progress: _quizEntries.isEmpty
              ? 0
              : (_quizIndex + (_answerChecked ? 1 : 0)) / _quizEntries.length,
          minHeight: 6,
        ),
        const SizedBox(height: 14),
        LearnLiteCard(
          backgroundColor: AppColors.charcoal,
          padding: EdgeInsets.zero,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                child: Column(
                  children: [
                    Text(
                      _identify
                          ? 'Choose the English meaning of'
                          : 'Choose the Subanen form for',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _prompt(question),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
              const DecorativeBorder(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < _choices.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnswerOptionTile(
              key: ValueKey('practice-choice-$index'),
              index: index,
              label: _choices[index],
              state: _optionState(index, question),
              onTap: _answerChecked || _isSaving
                  ? null
                  : () => setState(() {
                      _selectedAnswer = index;
                      _errorMessage = null;
                    }),
            ),
          ),
        if (_answerChecked)
          Semantics(
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectedIsCorrect
                    ? AppColors.successSoft
                    : AppColors.lightPink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedIsCorrect
                        ? Icons.celebration_rounded
                        : Icons.lightbulb_outline_rounded,
                    color: selectedIsCorrect
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedIsCorrect
                          ? 'Correct. Your workbook record is marked as learned.'
                          : 'Not quite. The source-list answer is ${_answer(question)}.',
                      style: TextStyle(
                        color: selectedIsCorrect
                            ? AppColors.success
                            : AppColors.redDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
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

  Widget _buildQuizHistory() => FutureBuilder<List<VocabularyQuizAttempt>>(
    future: _quizHistoryFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }
      if (snapshot.hasError) {
        return EmptyState(
          icon: Icons.history_outlined,
          title: 'Quiz history unavailable',
          message: userMessage(
            snapshot.error,
            fallback: 'Saved quiz results could not be loaded right now.',
          ),
        );
      }
      final attempts = snapshot.data ?? const [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Quiz history'),
          const SizedBox(height: 12),
          if (attempts.isEmpty)
            const EmptyState(
              icon: Icons.history_outlined,
              title: 'No vocabulary quiz attempts yet',
              message: 'Completed quiz results will be saved on this device.',
            )
          else
            for (final attempt in attempts) ...[
              LearnLiteCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: AppColors.white,
                  child: ExpansionTile(
                    title: Text(
                      '${attempt.score}% · ${attempt.correctAnswers} of '
                      '${attempt.totalQuestions} correct',
                    ),
                    subtitle: Text(
                      '${attempt.category} · '
                      '${friendlyDateTime(attempt.completedAt)}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final response in attempt.responses)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              response.isCorrect
                                  ? '${response.english}: ${response.selectedAnswer} ✓'
                                  : '${response.english}: ${response.selectedAnswer} '
                                        '(correct: ${response.correctAnswer})',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      );
    },
  );
}

class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.entry});

  final LocalVocabularyEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.creamSecondary.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.gray),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.reviewStatus,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 2),
              Text(
                entry.sourceLabel,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.gray),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Turns a flashcard over on the Y axis. Only one face is ever built, so
/// the visible text is always the face the learner sees.
class _FlipFlashcard extends StatelessWidget {
  const _FlipFlashcard({
    required this.showBack,
    required this.front,
    required this.back,
  });

  final bool showBack;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    final target = showBack ? pi : 0.0;
    if (reduceMotionOf(context)) return showBack ? back : front;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showingBack = angle > pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({
    required this.label,
    required this.word,
    required this.hint,
    required this.dark,
  });

  final String label;
  final String word;
  final String hint;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LearnLiteCard(
      backgroundColor: dark ? AppColors.charcoal : AppColors.white,
      borderRadius: 24,
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dark) const DecorativeBorder(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: dark ? AppColors.gold : AppColors.inkSoft,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    word,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: dark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: dark
                            ? AppColors.white.withValues(alpha: 0.6)
                            : AppColors.gray,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: dark
                                ? AppColors.white.withValues(alpha: 0.7)
                                : AppColors.gray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!dark) const DecorativeBorder(height: 8),
        ],
      ),
    );
  }
}
