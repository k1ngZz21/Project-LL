import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/features/content/content_gateway.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:learnlite/features/content/vocabulary_practice_screen.dart';

void main() {
  testWidgets('flashcard progress uses the vocabulary gateway', (tester) async {
    final gateway = _PracticeGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: VocabularyPracticeScreen(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.text('English meaning'), findsOneWidget);
    final card = find.byKey(const ValueKey('practice-flashcard'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Subanen form'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('practice-mark-learned')),
    );
    await tester.tap(find.byKey(const ValueKey('practice-mark-learned')));
    await tester.pumpAndSettle();

    expect(gateway.learnedVocabularyIds, contains(1));
    expect(find.text('Learned'), findsOneWidget);
  });

  testWidgets('quiz mode starts from workbook entries and shows source rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: VocabularyPracticeScreen(gateway: _PracticeGateway())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-choice-0')), findsOneWidget);
    expect(find.textContaining('· row '), findsOneWidget);
  });
}

class _PracticeGateway implements DictionaryGateway {
  final Set<int> learnedVocabularyIds = {};

  final List<LocalVocabularyEntry> _entries = const [
    LocalVocabularyEntry(
      id: 1,
      english: 'water',
      bisaya: '',
      subanen: 'tubig',
      module: '',
      topic: '',
      variety: '',
      alternateForms: '',
      source: 'Workbook',
      reviewStatus: 'Pending review',
      notes: '',
      sourceFile: 'Practice workbook.xlsx',
      sourceRow: 2,
    ),
    LocalVocabularyEntry(
      id: 2,
      english: 'house',
      bisaya: '',
      subanen: 'balay',
      module: '',
      topic: '',
      variety: '',
      alternateForms: '',
      source: 'Workbook',
      reviewStatus: 'Pending review',
      notes: '',
      sourceFile: 'Practice workbook.xlsx',
      sourceRow: 3,
    ),
    LocalVocabularyEntry(
      id: 3,
      english: 'sun',
      bisaya: '',
      subanen: 'adlaw',
      module: '',
      topic: '',
      variety: '',
      alternateForms: '',
      source: 'Workbook',
      reviewStatus: 'Pending review',
      notes: '',
      sourceFile: 'Practice workbook.xlsx',
      sourceRow: 4,
    ),
    LocalVocabularyEntry(
      id: 4,
      english: 'tree',
      bisaya: '',
      subanen: 'kahoy',
      module: '',
      topic: '',
      variety: '',
      alternateForms: '',
      source: 'Workbook',
      reviewStatus: 'Pending review',
      notes: '',
      sourceFile: 'Practice workbook.xlsx',
      sourceRow: 5,
    ),
  ];

  @override
  Future<LocalVocabularyCatalog> localVocabulary() async =>
      LocalVocabularyCatalog(
        vocabulary: [
          for (final entry in _entries)
            LocalVocabularyEntry(
              id: entry.id,
              english: entry.english,
              bisaya: entry.bisaya,
              subanen: entry.subanen,
              module: entry.module,
              topic: entry.topic,
              variety: entry.variety,
              alternateForms: entry.alternateForms,
              source: entry.source,
              reviewStatus: entry.reviewStatus,
              notes: entry.notes,
              sourceFile: entry.sourceFile,
              sourceRow: entry.sourceRow,
              isLearned: learnedVocabularyIds.contains(entry.id),
            ),
        ],
        starterList: const [],
        stillNeeded: const [],
        sourceRowCounts: const {'vocabulary': 4},
      );

  @override
  Future<void> setVocabularyLearningStatus({
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  }) async {
    if (learned) {
      learnedVocabularyIds.add(vocabularyId);
    } else {
      learnedVocabularyIds.remove(vocabularyId);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
