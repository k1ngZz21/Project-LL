import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/features/content/content_gateway.dart';
import 'package:learnlite/features/content/dictionary_screen.dart';

void main() {
  testWidgets('unverified dictionary results show a Pending review badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DictionaryScreen(gateway: _SearchGateway())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'gempya');
    await tester.tap(find.text('Search dictionary'));
    await tester.pumpAndSettle();

    expect(find.text('gempya gendao'), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary-pending-7')), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.byKey(const ValueKey('dictionary-verified-8')), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });
}

class _SearchGateway implements DictionaryGateway {
  @override
  Future<List<DictionaryTranslation>> searchDictionary(
    String query, {
    String sourceLanguage = 'Subanen',
    String targetLanguage = 'English',
  }) async => const [
    DictionaryTranslation(
      entry: DictionaryEntry(
        id: 8,
        subanenWord: 'verified word',
        englishTranslation: 'verified meaning',
        isVerified: true,
      ),
      sourceLanguage: 'Subanen',
      targetLanguage: 'English',
      translation: 'verified meaning',
    ),
    DictionaryTranslation(
      entry: DictionaryEntry(
        id: 7,
        subanenWord: 'gempya gendao',
        englishTranslation: 'Good day',
        reviewStatus: 'Pending review',
      ),
      sourceLanguage: 'Subanen',
      targetLanguage: 'English',
      translation: 'Good day',
    ),
  ];

  @override
  Future<List<String>> recentDictionarySearches() async => const [];

  @override
  Future<void> recordDictionarySearch(String query) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
