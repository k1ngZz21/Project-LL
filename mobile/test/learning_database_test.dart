import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/core/bundled_learning_content.dart';
import 'package:learnlite/core/learning_database.dart';
import 'package:learnlite/features/auth/auth_gateway.dart';
import 'package:learnlite/features/content/content_gateway.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late LearningDatabase database;

  setUp(() async {
    database = LearningDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await database.database;
  });

  tearDown(() => database.close());

  test('creates a versioned database with foreign keys enabled', () async {
    final db = await database.database;
    expect(
      (await db.rawQuery('PRAGMA user_version')).single['user_version'],
      3,
    );
    expect(
      (await db.rawQuery('PRAGMA foreign_keys')).single['foreign_keys'],
      1,
    );

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll([
        'learners',
        'vocabulary',
        'learning_modules',
        'lessons',
        'quiz_questions',
        'quiz_answers',
        'quiz_results',
        'learning_progress',
        'lesson_completions',
        'learning_history',
      ]),
    );
  });

  test('migrates version two learners without losing profile data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'learnlite-migration-',
    );
    final path = p.join(directory.path, 'learnlite-v2.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE learners (
              uid TEXT PRIMARY KEY,
              email TEXT NOT NULL,
              username TEXT NOT NULL,
              full_name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE quiz_results (
              uid TEXT NOT NULL,
              module_id INTEGER,
              lesson_index INTEGER NOT NULL,
              completed_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE learning_history (
              uid TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE dictionary_searches (
              uid TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.insert('learners', {
            'uid': 'existing-learner',
            'email': 'existing@example.test',
            'username': 'existing_learner',
            'full_name': 'Existing Learner',
            'created_at': '2025-01-01T00:00:00.000Z',
            'updated_at': '2025-02-01T00:00:00.000Z',
          });
        },
      ),
    );
    await legacy.close();

    final upgraded = LearningDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    try {
      final db = await upgraded.database;
      final profile = await upgraded.learner('existing-learner');
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );

      expect(
        (await db.rawQuery('PRAGMA user_version')).single['user_version'],
        3,
      );
      expect(profile?['full_name'], 'Existing Learner');
      expect(profile?['username'], 'existing_learner');
      expect(profile?['last_login'], '2025-02-01T00:00:00.000Z');
      expect(
        indexes.map((row) => row['name']),
        containsAll([
          'idx_quiz_results_owner_attempt',
          'idx_learning_history_owner_created',
          'idx_dictionary_searches_owner_created',
        ]),
      );
    } finally {
      await upgraded.close();
      await directory.delete(recursive: true);
    }
  });

  test('repeated profile initialization preserves user information', () async {
    await database.createLearner(
      uid: 'profile-owner',
      email: 'first@example.test',
      username: 'profile_owner',
      fullName: 'Original Name',
      learningPreference: 'culture',
    );
    await database.updateLearner('profile-owner', {'nickname': 'Original'});

    await database.createLearner(
      uid: 'profile-owner',
      email: 'updated@example.test',
      username: 'different_name',
      fullName: 'Changed Name',
      learningPreference: 'language',
    );
    await database.ensureLearner(
      uid: 'profile-owner',
      email: 'updated@example.test',
      fullName: 'Changed Name',
    );
    await database.recordLearnerLogin(
      uid: 'profile-owner',
      email: 'updated@example.test',
    );

    final profile = await database.learner('profile-owner');
    expect(profile?['email'], 'updated@example.test');
    expect(profile?['username'], 'profile_owner');
    expect(profile?['full_name'], 'Original Name');
    expect(profile?['learning_preference'], 'culture');
    expect(profile?['nickname'], 'Original');
    expect(DateTime.tryParse(profile?['last_login'] as String), isNotNull);
  });

  test('rejects learner progress with a missing vocabulary entry', () async {
    await database.createLearner(
      uid: 'integrity-owner',
      email: 'integrity@example.test',
      username: 'integrity_owner',
      fullName: 'Integrity Owner',
      learningPreference: 'both',
    );

    await expectLater(
      database.setVocabularyProgress(
        uid: 'integrity-owner',
        vocabularyId: -1,
        learned: true,
        bookmarked: false,
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'initializes empty published-module progress separately per learner',
    () async {
      final moduleId = await database.saveModule({
        'title': 'Progress initialization',
        'description': 'A local module',
        'lessons': [
          {'title': 'First lesson', 'content': 'Saved on this device.'},
        ],
      });
      await database.setModulePublished(moduleId, true);
      for (final learner in [
        ('progress-a', 'progress_a'),
        ('progress-b', 'progress_b'),
      ]) {
        await database.createLearner(
          uid: learner.$1,
          email: '${learner.$2}@example.test',
          username: learner.$2,
          fullName: learner.$2,
          learningPreference: 'both',
        );
      }

      expect(await database.moduleProgress('progress-a', moduleId), {
        'last_lesson_index': null,
        'completed_lesson_indices': <int>[],
      });
      await database.startLesson('progress-a', moduleId, 0);

      expect(
        (await database.moduleProgress(
          'progress-a',
          moduleId,
        ))?['last_lesson_index'],
        0,
      );
      expect(
        (await database.moduleProgress(
          'progress-b',
          moduleId,
        ))?['last_lesson_index'],
        isNull,
      );
    },
  );

  test('imports all bundled vocabulary without merging source rows', () async {
    final catalog = await LocalVocabularyRepository().load();
    await database.seedVocabulary(catalog);

    final rows = await database.vocabulary();
    expect(
      rows,
      hasLength(
        catalog.vocabulary.length +
            catalog.stillNeeded.length +
            catalog.starterList.length,
      ),
    );
    expect(catalog.sourceRowCounts, {
      'vocabulary': 169,
      'still_needed': 68,
      'starter_list': 82,
    });
    expect(
      rows.where((row) => row['review_status'] == 'Pending review'),
      isNotEmpty,
    );
    expect(
      rows.where(
        (row) =>
            row['subanen'] == '' &&
            row['review_status'] == 'Needs Subanen form',
      ),
      isNotEmpty,
    );
    await database.seedVocabulary(catalog);
    expect(
      await database.vocabulary(),
      hasLength(
        catalog.vocabulary.length +
            catalog.stillNeeded.length +
            catalog.starterList.length,
      ),
    );
  });

  test(
    'loads vocabulary and learning status from SQLite per learner',
    () async {
      final catalog = await LocalVocabularyRepository().load();
      await database.seedVocabulary(catalog);
      await database.createLearner(
        uid: 'vocabulary-learner',
        email: 'vocabulary@example.test',
        username: 'vocabulary_learner',
        fullName: 'Vocabulary Learner',
        learningPreference: 'both',
      );
      final row = (await database.vocabulary()).first;
      final vocabularyId = row['id']! as int;
      await database.setVocabularyProgress(
        uid: 'vocabulary-learner',
        vocabularyId: vocabularyId,
        learned: true,
        bookmarked: true,
      );

      final learnerCatalog = await database.vocabularyCatalog(
        uid: 'vocabulary-learner',
      );
      final otherCatalog = await database.vocabularyCatalog(
        uid: 'offline-guest',
      );
      final entry = learnerCatalog
          .search('')
          .singleWhere((item) => item.id == vocabularyId);
      final otherEntry = otherCatalog
          .search('')
          .singleWhere((item) => item.id == vocabularyId);

      expect(learnerCatalog.sourceRowCounts, catalog.sourceRowCounts);
      expect(entry.isLearned, isTrue);
      expect(entry.isBookmarked, isTrue);
      expect(otherEntry.isLearned, isFalse);
      expect(otherEntry.isBookmarked, isFalse);
    },
  );

  test(
    'persists lessons, quiz attempts, and per-UID progress idempotently',
    () async {
      await database.createLearner(
        uid: 'learner-a',
        email: 'a@example.test',
        username: 'learner_a',
        fullName: 'Learner A',
        learningPreference: 'both',
      );
      await database.createLearner(
        uid: 'learner-b',
        email: 'b@example.test',
        username: 'learner_b',
        fullName: 'Learner B',
        learningPreference: 'language',
      );
      final moduleId = await database.saveModule({
        'title': 'Local lesson',
        'description': 'Stored offline',
        'lessons': [
          {
            'title': 'Lesson one',
            'content': 'This content is saved locally.',
            'quiz': [
              {
                'question': 'Which answer is correct?',
                'choices': ['Incorrect', 'Correct'],
                'correct_answer_index': 1,
                'explanation': 'The second option is correct.',
              },
            ],
          },
        ],
      });
      await database.setModulePublished(moduleId, true);

      expect(await database.completeLesson('learner-a', moduleId, 0), isTrue);
      expect(await database.completeLesson('learner-a', moduleId, 0), isFalse);
      final learnerModule = await database.module(moduleId, uid: 'learner-a');
      final otherModule = await database.module(moduleId, uid: 'learner-b');
      expect(learnerModule?['completed_lessons'], 1);
      expect(otherModule?['completed_lessons'], 0);

      final result = await database.submitQuiz('learner-a', moduleId, 0, [1]);
      expect(result['score'], 100);
      expect(result['correct_answers'], 1);
      expect(result['questions'], [
        {
          'question': 'Which answer is correct?',
          'choices': ['Incorrect', 'Correct'],
          'selected_answer_index': 1,
          'correct_answer_index': 1,
          'explanation': 'The second option is correct.',
        },
      ]);
      expect(
        await database.quizAttempts('learner-a', moduleId, 0),
        hasLength(1),
      );
      expect((await database.learner('learner-a'))?['xp'], 16);
      expect((await database.learner('learner-b'))?['xp'], 0);
    },
  );

  test('seeds the bundled offline module once without replacing it', () async {
    final moduleId = await database.seedBundledModule(
      key: bundledOfflineModuleKey,
      module: bundledOfflineModule,
    );
    final repeatedId = await database.seedBundledModule(
      key: bundledOfflineModuleKey,
      module: bundledOfflineModule,
    );

    expect(repeatedId, moduleId);
    final module = await database.module(moduleId, uid: null);
    expect(module?['is_published'], 1);
    expect(module?['lesson_count'], 3);
    expect(
      (module?['lessons'] as List).every(
        (lesson) => (lesson['quiz'] as List).isNotEmpty,
      ),
      isTrue,
    );
    expect(
      (module?['description'] as String).toLowerCase(),
      contains('not an official'),
    );
    expect(await database.modules(uid: null), hasLength(1));
  });

  test('offline guest can complete quizzes and save local progress', () async {
    await database.seedBundledModule(
      key: bundledOfflineModuleKey,
      module: bundledOfflineModule,
    );
    final gateway = FirebaseAuthGateway(database: database);
    final module = (await gateway.fetchModules()).single;

    await gateway.startModuleLesson(module.id, 0);
    final result = await gateway.submitLessonQuiz(module.id, 0, [0]);
    final updatedModule = await gateway.fetchModule(module.id);
    final attempts = await gateway.fetchLessonQuizAttempts(module.id, 0);

    expect(result.score, 100);
    expect(result.lessonXpAwarded, 15);
    expect(result.totalXpAwarded, 16);
    expect(updatedModule.lessons.first.completed, isTrue);
    expect(updatedModule.lastLessonIndex, 0);
    expect(attempts, hasLength(1));
    expect((await database.learner('offline-guest'))?['xp'], 16);
  });

  test(
    'vocabulary quiz history survives closing and reopening SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'learnlite-vocabulary-quiz-',
      );
      final path = p.join(directory.path, 'learnlite.db');
      final firstOpen = LearningDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      const responses = [
        VocabularyQuizResponse(
          english: 'water',
          selectedAnswer: 'tubig',
          correctAnswer: 'tubig',
        ),
        VocabularyQuizResponse(
          english: 'house',
          selectedAnswer: 'balay',
          correctAnswer: 'balay',
        ),
      ];

      try {
        final firstGateway = FirebaseAuthGateway(database: firstOpen);
        final attempt = await firstGateway.saveVocabularyQuizAttempt(
          category: 'Everyday',
          responses: responses,
        );
        expect(attempt.score, 100);
        await firstOpen.close();

        final reopened = LearningDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          final history = await FirebaseAuthGateway(database: reopened)
              .fetchVocabularyQuizAttempts();
          expect(history, hasLength(1));
          expect(history.single.category, 'Everyday');
          expect(history.single.correctAnswers, 2);
          expect(history.single.responses, hasLength(2));
        } finally {
          await reopened.close();
        }
      } finally {
        await firstOpen.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('longest streak reflects the full activity history', () async {
    final today = DateTime.now().toUtc();
    await database.createLearner(
      uid: 'offline-guest',
      email: '',
      username: 'offline_guest',
      fullName: 'Offline learner',
      learningPreference: 'both',
    );
    for (var index = 0; index < 3; index++) {
      final moduleId = await database.saveModule({
        'title': 'Historical streak $index',
        'description': 'Streak test',
        'lessons': [
          {'title': 'Lesson', 'content': 'Content'},
        ],
      });
      await (await database.database).insert('lesson_completions', {
        'uid': 'offline-guest',
        'module_id': moduleId,
        'lesson_index': 0,
        'completed_at': today
            .subtract(Duration(days: 12 - index))
            .toIso8601String(),
      });
    }

    final rewards = await FirebaseAuthGateway(database: database)
        .fetchRewards();

    expect(rewards.streak, 0);
    expect(rewards.longestStreak, 3);
  });

  test(
    'local vocabulary, lessons, quiz results, and progress survive reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'learnlite-persistence-',
      );
      final path = p.join(directory.path, 'learnlite.db');
      final firstOpen = LearningDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );

      try {
        await firstOpen.database;
        await firstOpen.seedVocabulary(
          await LocalVocabularyRepository().load(),
        );
        await firstOpen.createLearner(
          uid: 'offline-guest',
          email: '',
          username: 'offline_guest',
          fullName: 'Offline learner',
          learningPreference: 'both',
        );
        final vocabularyRow = (await firstOpen.vocabulary()).first;
        final vocabularyId = vocabularyRow['id']! as int;
        await firstOpen.setVocabularyProgress(
          uid: 'offline-guest',
          vocabularyId: vocabularyId,
          learned: true,
          bookmarked: true,
        );
        final moduleId = await firstOpen.seedBundledModule(
          key: bundledOfflineModuleKey,
          module: bundledOfflineModule,
        );
        await firstOpen.startLesson('offline-guest', moduleId, 0);
        await firstOpen.submitQuiz('offline-guest', moduleId, 0, [0]);
        await firstOpen.close();

        final reopened = LearningDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          expect((await reopened.learner('offline-guest'))?['xp'], 16);
          expect(
            (await reopened.vocabularyProgress('offline-guest')).single,
            containsPair('is_learned', 1),
          );
          final module = await reopened.module(moduleId, uid: 'offline-guest');
          expect((module?['lessons'] as List).first['completed'], isTrue);
          expect(
            await reopened.quizAttempts('offline-guest', moduleId, 0),
            hasLength(1),
          );
          expect(await reopened.vocabulary(), isNotEmpty);
        } finally {
          await reopened.close();
        }
      } finally {
        await firstOpen.close();
        await directory.delete(recursive: true);
      }
    },
  );

  group('Phase 1 regressions', () {
    test('dictionary search returns pending entries, labelled and ranked after verified ones', () async {
      await database.seedVocabulary(await LocalVocabularyRepository().load());
      final gateway = FirebaseAuthGateway(database: database);

      final pending = await gateway.searchDictionary('gempya');
      expect(pending, isNotEmpty);
      expect(pending.every((result) => !result.entry.isVerified), isTrue);
      expect(pending.first.entry.reviewStatus, 'Pending review');

      final db = await database.database;
      final lastId = pending.last.entry.id;
      await db.update(
        'vocabulary',
        {'is_verified': 1},
        where: 'id = ?',
        whereArgs: [lastId],
      );
      final ranked = await gateway.searchDictionary('gempya');
      expect(ranked.first.entry.id, lastId);
      expect(ranked.first.entry.isVerified, isTrue);
    });

    Future<int> threeLessonModule(LearningDatabase target) async {
      final moduleId = await target.saveModule({
        'title': 'Local day module',
        'description': 'Local day rewards',
        'lessons': [
          for (var index = 0; index < 3; index++)
            {'title': 'Lesson $index', 'content': 'Content $index'},
        ],
      });
      await target.setModulePublished(moduleId, true);
      return moduleId;
    }

    test('daily bonus follows the device local calendar day', () async {
      var now = DateTime(2026, 11, 19, 0, 30);
      final clocked = LearningDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        clock: () => now,
      );
      try {
        await clocked.createLearner(
          uid: 'learner-a',
          email: 'a@example.test',
          username: 'learner_a',
          fullName: 'Learner A',
          learningPreference: 'both',
        );
        final moduleId = await threeLessonModule(clocked);

        // Just after local midnight: first lesson of the local day earns
        // the daily bonus.
        expect(await clocked.completeLesson('learner-a', moduleId, 0), isTrue);
        expect((await clocked.learner('learner-a'))?['xp'], 15);

        // Late the same local day: no second daily bonus.
        now = DateTime(2026, 11, 19, 23, 30);
        expect(await clocked.completeLesson('learner-a', moduleId, 1), isTrue);
        expect((await clocked.learner('learner-a'))?['xp'], 25);

        // Next local day: the daily bonus is available again.
        now = DateTime(2026, 11, 20, 0, 10);
        expect(await clocked.completeLesson('learner-a', moduleId, 2), isTrue);
        expect((await clocked.learner('learner-a'))?['xp'], 40);

        final bonuses = await (await clocked.database).query(
          'learning_history',
          columns: ['entity_id'],
          where: 'uid = ? AND event_type = ?',
          whereArgs: ['learner-a', 'daily_bonus_awarded'],
          orderBy: 'entity_id',
        );
        expect(bonuses.map((row) => row['entity_id']), [
          '2026-11-19',
          '2026-11-20',
        ]);
      } finally {
        await clocked.close();
      }
    });

    test('streak and daily quest use local calendar days', () async {
      var now = DateTime(2026, 11, 18, 7);
      final clocked = LearningDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        clock: () => now,
      );
      try {
        await clocked.createLearner(
          uid: 'offline-guest',
          email: '',
          username: 'offline_guest',
          fullName: 'Offline learner',
          learningPreference: 'both',
        );
        final moduleId = await threeLessonModule(clocked);
        await clocked.completeLesson('offline-guest', moduleId, 0);
        now = DateTime(2026, 11, 19, 7);
        await clocked.completeLesson('offline-guest', moduleId, 1);
        now = DateTime(2026, 11, 19, 9);

        final rewards = await FirebaseAuthGateway(database: clocked)
            .fetchRewards();

        expect(rewards.today, DateTime.utc(2026, 11, 19));
        expect(rewards.streak, 2);
        expect(rewards.dailyQuest.completed, isTrue);
        expect(rewards.dailyQuest.xpAwarded, 5);
        expect(rewards.calendar.last.isToday, isTrue);
        expect(rewards.calendar.last.active, isTrue);
      } finally {
        await clocked.close();
      }
    });
  });
}
