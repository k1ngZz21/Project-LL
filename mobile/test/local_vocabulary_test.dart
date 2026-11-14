import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalVocabularyCatalog catalog;

  setUpAll(() async {
    catalog = await LocalVocabularyRepository().load();
  });

  test('loads the complete original workbook row sets', () {
    expect(catalog.sourceRowCounts['vocabulary'], 169);
    expect(catalog.sourceRowCounts['still_needed'], 68);
    expect(catalog.sourceRowCounts['starter_list'], 82);
    expect(catalog.vocabulary, hasLength(169));
    expect(catalog.starterList, hasLength(82));
    expect(catalog.stillNeeded, isNotEmpty);
  });

  test('preserves pending-review status and searches offline vocabulary', () {
    final result = catalog.search(
      'gempya gendao',
      source: 'LearnLite vocabulary',
    );

    expect(result, hasLength(1));
    expect(result.single.english, 'Good day');
    expect(result.single.reviewStatus, 'Pending review');
    expect(result.single.sourceFile, 'LearnLite-Subanen-Vocabulary.xlsx');
  });

  test('does not silently fill missing Subanen forms', () {
    final result = catalog.search(
      'Good morning, family',
      source: 'Still needed',
    );

    expect(result, hasLength(1));
    expect(result.single.subanen, isEmpty);
    expect(result.single.needsSubanenForm, isTrue);
    expect(result.single.reviewStatus, 'Needs Subanen form');
  });

  test('preserves starter-list provenance and verification warning', () {
    final result = catalog.search('sanu bok', source: 'Starter list');

    expect(result, hasLength(1));
    expect(result.single.english, 'how');
    expect(
      result.single.reviewStatus,
      contains('verify with a fluent speaker'),
    );
    expect(result.single.sourceFile, 'Subanen_Vocabulary_Starter_List.xlsx');
  });
}
