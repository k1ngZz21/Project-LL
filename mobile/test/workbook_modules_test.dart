import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/core/learning_database.dart';
import 'package:learnlite/core/workbook_modules.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late List<LocalVocabularyEntry> workbook;

  setUpAll(() async {
    workbook = (await LocalVocabularyRepository().load()).vocabulary;
  });

  group('workbook module generation', () {
    test('builds one module per workbook module and one lesson per topic', () {
      final seeds = buildWorkbookModules(workbook);

      expect(seeds.map((seed) => seed.module['title']), [
        'Basic Greetings',
        'Family & Community',
        'Numbers & Counting',
        'Everyday Phrases',
        'Culture & Traditions',
      ]);
      expect(seeds.map((seed) => seed.key), [
        for (var n = 1; n <= 5; n++) 'workbook-module-$n',
      ]);

      final lessonCount = seeds.fold<int>(
        0,
        (sum, seed) => sum + (seed.module['lessons'] as List).length,
      );
      final topics = {
        for (final entry in workbook)
          if (workbookModuleNumber(entry.module) != null &&
              entry.topic.trim().isNotEmpty)
            '${entry.module}|${entry.topic}',
      };
      expect(lessonCount, topics.length);
      expect(lessonCount, 19);
    });

    test('quiz answers and choices come only from workbook rows', () {
      for (final seed in buildWorkbookModules(workbook)) {
        final moduleTitle = seed.module['title'] as String;
        final moduleSubanen = {
          for (final entry in workbook)
            if (workbookModuleName(entry.module) == moduleTitle)
              entry.subanen.trim().toLowerCase(),
        };
        for (final lesson in seed.module['lessons'] as List) {
          final lessonTitle = lesson['title'] as String;
          final lessonRows = workbook
              .where(
                (entry) => isWorkbookLessonEntry(
                  entry,
                  moduleTitle: moduleTitle,
                  lessonTitle: lessonTitle,
                ),
              )
              .toList();
          expect(lessonRows, isNotEmpty, reason: lessonTitle);

          final quiz = lesson['quiz'] as List;
          expect(quiz.length, lessThanOrEqualTo(workbookQuizQuestionLimit));
          for (final question in quiz) {
            final choices = (question['choices'] as List).cast<String>();
            final correct = choices[question['correct_answer_index'] as int];
            // The right answer is the Subanen form of a row in this lesson
            // whose English meaning the question quotes.
            final match = lessonRows.where(
              (row) =>
                  row.subanen.trim() == correct &&
                  (question['question'] as String).contains(
                    '"${row.english.trim()}"',
                  ),
            );
            expect(match, isNotEmpty, reason: question['question'] as String);
            // Every choice is a Subanen form from the same module; no
            // invented answers, and no duplicate choices.
            for (final choice in choices) {
              expect(moduleSubanen, contains(choice.toLowerCase()));
            }
            expect(
              choices.map((choice) => choice.toLowerCase()).toSet().length,
              choices.length,
            );
            expect(
              question['explanation'] as String,
              contains('Workbook row ${match.first.sourceRow}'),
            );
          }
        }
      }
    });

    test('generation is deterministic', () {
      expect(
        jsonEncode([
          for (final seed in buildWorkbookModules(workbook)) seed.module,
        ]),
        jsonEncode([
          for (final seed in buildWorkbookModules(workbook)) seed.module,
        ]),
      );
    });

    test('rows without a numbered module or topic are not made into lessons',
        () {
      final seeds = buildWorkbookModules(const [
        LocalVocabularyEntry(
          english: 'water',
          bisaya: '',
          subanen: 'tubig',
          module: 'Nature and environment',
          topic: '',
          variety: '',
          alternateForms: '',
          source: '',
          reviewStatus: 'Starter list',
          notes: '',
          sourceFile: workbookSourceFile,
          sourceRow: 3,
        ),
      ]);
      expect(seeds, isEmpty);
    });
  });

  group('workbook module seeding', () {
    late LearningDatabase database;

    setUp(() async {
      database = LearningDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      await database.database;
    });

    tearDown(() => database.close());

    test('installs the modules once and skips while unchanged', () async {
      final repository = LocalVocabularyRepository();
      expect(await database.seedWorkbookModulesIfChanged(repository), isTrue);
      final modules = await database.modules(uid: null);
      expect(modules.length, 5);
      expect(
        modules.fold<int>(0, (sum, m) => sum + (m['lesson_count'] as int)),
        19,
      );

      expect(await database.seedWorkbookModulesIfChanged(repository), isFalse);
      expect((await database.modules(uid: null)).length, 5);
    });

    test('an updated workbook keeps module IDs and learner progress', () async {
      final seeds = buildWorkbookModules(workbook);
      await database.seedWorkbookModules(seeds, fingerprint: 'first');
      final before = await database.modules(uid: null);
      final greetingsId = before.first['id']! as int;

      await database.createLearner(
        uid: 'learner-a',
        email: 'a@example.test',
        username: 'learner_a',
        fullName: 'Learner A',
        learningPreference: 'language',
      );
      expect(await database.completeLesson('learner-a', greetingsId, 0), isTrue);

      // A corrected workbook: the first lesson's text changes.
      final changed = [
        for (final seed in seeds)
          WorkbookModuleSeed(
            key: seed.key,
            module: {
              ...seed.module,
              'description': '${seed.module['description']} (updated)',
            },
          ),
      ];
      await database.seedWorkbookModules(changed, fingerprint: 'second');

      final after = await database.modules(uid: 'learner-a');
      expect(after.length, 5);
      expect(after.map((m) => m['id']), before.map((m) => m['id']));
      expect(after.first['description'], endsWith('(updated)'));
      expect(after.first['completed_lessons'], 1);
    });
  });
}
