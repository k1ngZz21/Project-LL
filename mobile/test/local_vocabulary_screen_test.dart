import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/features/content/content_gateway.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:learnlite/features/content/local_vocabulary_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    _VocabularyGateway gateway,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocalVocabularyScreen(gateway: gateway)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('large vocabulary lists are built lazily', (tester) async {
    await pumpScreen(tester, _VocabularyGateway(count: 300));

    expect(find.text('300 workbook entries'), findsOneWidget);
    // Only cards near the viewport exist; the last entry has not been built.
    expect(find.byKey(const ValueKey('vocabulary-entry-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('vocabulary-entry-300')), findsNothing);
  });

  testWidgets('search filters entries after the debounce', (tester) async {
    await pumpScreen(tester, _VocabularyGateway(count: 300));

    await tester.enterText(find.byType(TextField), 'word 300');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('1 workbook entry'), findsOneWidget);
    expect(find.byKey(const ValueKey('vocabulary-entry-300')), findsOneWidget);
    expect(find.byKey(const ValueKey('vocabulary-entry-1')), findsNothing);
  });

  testWidgets('marking a word learned keeps the list on screen', (
    tester,
  ) async {
    final gateway = _VocabularyGateway(count: 20);
    await pumpScreen(tester, gateway);

    await tester.tap(find.byTooltip('Mark as learned').first);
    await tester.pump();

    // The previous results stay visible while the catalog reloads.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('20 workbook entries'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(gateway.learnedIds, contains(1));
    expect(find.byTooltip('Mark as not learned'), findsOneWidget);
  });
}

class _VocabularyGateway implements DictionaryGateway {
  _VocabularyGateway({required this.count});

  final int count;
  final Set<int> learnedIds = {};

  @override
  Future<LocalVocabularyCatalog> localVocabulary() async =>
      LocalVocabularyCatalog(
        vocabulary: [
          for (var index = 1; index <= count; index++)
            LocalVocabularyEntry(
              id: index,
              english: 'word $index',
              bisaya: '',
              subanen: 'subanen $index',
              module: '',
              topic: '',
              variety: '',
              alternateForms: '',
              source: 'Workbook',
              reviewStatus: 'Pending review',
              notes: '',
              sourceFile: 'Test workbook.xlsx',
              sourceRow: index + 1,
              isLearned: learnedIds.contains(index),
            ),
        ],
        starterList: const [],
        stillNeeded: const [],
        sourceRowCounts: {'vocabulary': count},
      );

  @override
  Future<void> setVocabularyLearningStatus({
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  }) async {
    if (learned) {
      learnedIds.add(vocabularyId);
    } else {
      learnedIds.remove(vocabularyId);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
