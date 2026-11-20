import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/core/learning_database.dart';
import 'package:learnlite/core/vocabulary_pdf.dart';
import 'package:learnlite/features/auth/auth_gateway.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('the word list covers every bundled entry and invents none', () async {
    final catalog = await LocalVocabularyRepository().load();
    final (:withForm, :stillNeeded) = vocabularyPdfSections(catalog);
    final all = [
      ...catalog.vocabulary,
      ...catalog.starterList,
      ...catalog.stillNeeded,
    ];

    expect(withForm.length + stillNeeded.length, all.length,
        reason: 'no entry is dropped');
    expect(withForm, isNotEmpty);
    expect(withForm.every((entry) => entry.subanen.trim().isNotEmpty), isTrue);
    expect(
      stillNeeded.every((entry) => entry.subanen.trim().isEmpty),
      isTrue,
      reason: 'missing forms are listed as still needed, never filled in',
    );
    final sorted = withForm.map((e) => e.subanen.toLowerCase()).toList();
    expect(sorted, [...sorted]..sort());

    final bytes = await buildVocabularyPdf(
      catalog,
      generatedAt: DateTime(2026, 11, 20),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(10 * 1024));
  });

  test('the word list pack is offered, saved, opened offline and removed',
      () async {
    final database = LearningDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    await database.seedVocabularyIfChanged(LocalVocabularyRepository());
    final gateway = FirebaseAuthGateway(database: database);

    var packs = await gateway.availableContentPacks();
    final offered = packs.singleWhere((pack) => pack.id == vocabularyPdfPackId);
    expect(offered.type, 'pdf');
    expect(offered.downloaded, isFalse);
    await expectLater(
      gateway.fetchResourceBytes(vocabularyPdfResourceKey),
      throwsA(isA<AuthFailure>()),
    );

    await gateway.downloadContentPack(vocabularyPdfPackId);
    packs = await gateway.availableContentPacks();
    final saved = packs.where((pack) => pack.id == vocabularyPdfPackId);
    expect(saved, hasLength(1), reason: 'listed once, not duplicated');
    expect(saved.single.downloaded, isTrue);
    expect(saved.single.sizeBytes, greaterThan(10 * 1024));
    final bytes = await gateway.fetchResourceBytes(vocabularyPdfResourceKey);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');

    await gateway.downloadContentPack(vocabularyPdfPackId);
    expect(
      (await gateway.downloadedContentPacks())
          .where((pack) => pack.id == vocabularyPdfPackId),
      hasLength(1),
      reason: 'downloading again replaces instead of duplicating',
    );

    await gateway.removeContentPack(vocabularyPdfPackId);
    packs = await gateway.availableContentPacks();
    expect(
      packs.singleWhere((pack) => pack.id == vocabularyPdfPackId).downloaded,
      isFalse,
    );
  });
}
