import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../features/content/local_vocabulary.dart';

class LearningDatabase {
  LearningDatabase({this.factory, this.databasePath});

  static final instance = LearningDatabase();

  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<void> close() async {
    final opened = _opening;
    _opening = null;
    if (opened != null) await (await opened).close();
  }

  Future<Database> _open() async {
    final databaseOpener = factory ?? databaseFactory;
    final path =
        databasePath ?? p.join(await getDatabasesPath(), 'learnlite.db');
    return databaseOpener.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _createVersionOne(db);
          await _createVersionTwo(db);
          await _upgradeToThree(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 1 && newVersion >= 1) {
            await _createVersionOne(db);
          }
          if (oldVersion < 2 && newVersion >= 2) {
            await _createVersionTwo(db);
          }
          if (oldVersion < 3 && newVersion >= 3) {
            await _upgradeToThree(db);
          }
        },
      ),
    );
  }

  Future<void> _createVersionOne(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learners (
        uid TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        full_name TEXT NOT NULL,
        nickname TEXT,
        avatar_id TEXT,
        outfit_color TEXT,
        avatar_completed INTEGER NOT NULL DEFAULT 0,
        learning_preference TEXT NOT NULL DEFAULT 'both',
        xp INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_key TEXT NOT NULL UNIQUE,
        source_file TEXT NOT NULL,
        source_row INTEGER,
        english TEXT NOT NULL DEFAULT '',
        bisaya TEXT NOT NULL DEFAULT '',
        subanen TEXT NOT NULL DEFAULT '',
        module TEXT NOT NULL DEFAULT '',
        topic TEXT NOT NULL DEFAULT '',
        variety TEXT NOT NULL DEFAULT '',
        alternate_forms TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT '',
        review_status TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        pronunciation TEXT,
        audio_url TEXT,
        is_verified INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_modules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_published INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        module_id INTEGER NOT NULL REFERENCES learning_modules(id) ON DELETE CASCADE,
        lesson_index INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        phrase TEXT,
        pronunciation TEXT,
        audio_url TEXT,
        image_url TEXT,
        cultural_note TEXT,
        keywords_json TEXT NOT NULL DEFAULT '[]',
        UNIQUE (module_id, lesson_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        question TEXT NOT NULL,
        correct_answer_index INTEGER NOT NULL,
        explanation TEXT,
        UNIQUE (lesson_id, position)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_answers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        answer_text TEXT NOT NULL,
        UNIQUE (question_id, position)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
        module_id INTEGER REFERENCES learning_modules(id) ON DELETE SET NULL,
        lesson_index INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        correct_answers INTEGER NOT NULL,
        answers_json TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeToThree(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(learners)');
    if (!columns.any((column) => column['name'] == 'last_login')) {
      await db.execute('ALTER TABLE learners ADD COLUMN last_login TEXT');
    }
    await db.execute('''
      UPDATE learners
      SET last_login = COALESCE(last_login, updated_at, created_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_quiz_results_owner_attempt
      ON quiz_results(uid, module_id, lesson_index, completed_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_learning_history_owner_created
      ON learning_history(uid, created_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_dictionary_searches_owner_created
      ON dictionary_searches(uid, created_at DESC)
    ''');
  }

  Future<void> _createVersionTwo(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_progress (
        uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
        module_id INTEGER NOT NULL REFERENCES learning_modules(id) ON DELETE CASCADE,
        last_lesson_index INTEGER,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (uid, module_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_completions (
        uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
        module_id INTEGER NOT NULL REFERENCES learning_modules(id) ON DELETE CASCADE,
        lesson_index INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        PRIMARY KEY (uid, module_id, lesson_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vocabulary_progress (
        uid TEXT NOT NULL REFERENCES learners(uid) ON DELETE CASCADE,
        vocabulary_id INTEGER NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
        is_learned INTEGER NOT NULL DEFAULT 0,
        is_bookmarked INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (uid, vocabulary_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_history (
        id TEXT PRIMARY KEY,
        uid TEXT,
        event_type TEXT NOT NULL,
        entity_id TEXT,
        event_data_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary_searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        query TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content_packs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        data_json TEXT NOT NULL,
        media_json TEXT NOT NULL DEFAULT '{}',
        downloaded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_resources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        media_type TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        module_id INTEGER,
        lesson_index INTEGER,
        vocabulary_id INTEGER,
        bytes BLOB NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> seedVocabulary(LocalVocabularyCatalog catalog) async {
    final db = await database;
    await db.transaction((txn) async {
      Future<void> insertRows(
        List<LocalVocabularyEntry> entries,
        String dataset,
      ) async {
        for (final entry in entries) {
          await txn.insert('vocabulary', {
            'source_key': '$dataset:${entry.sourceFile}:${entry.sourceRow}',
            'source_file': entry.sourceFile,
            'source_row': entry.sourceRow,
            'english': entry.english,
            'bisaya': entry.bisaya,
            'subanen': entry.subanen,
            'module': entry.module,
            'topic': entry.topic,
            'variety': entry.variety,
            'alternate_forms': entry.alternateForms,
            'source': entry.source,
            'review_status': entry.reviewStatus,
            'notes': entry.notes,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await insertRows(catalog.vocabulary, 'vocabulary');
      await insertRows(catalog.stillNeeded, 'still-needed');
      await insertRows(catalog.starterList, 'starter-list');
      await txn.insert('app_metadata', {
        'key': 'vocabulary_source_row_counts_v1',
        'value': jsonEncode(catalog.sourceRowCounts),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<LocalVocabularyCatalog> vocabularyCatalog({String? uid}) async {
    final db = await database;
    final rows = await db.query(
      'vocabulary',
      orderBy: 'source_file, source_row, id',
    );
    final progress = uid == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'vocabulary_progress',
            where: 'uid = ?',
            whereArgs: [uid],
          );
    final progressById = {
      for (final item in progress) item['vocabulary_id']: item,
    };
    final vocabulary = <LocalVocabularyEntry>[];
    final stillNeeded = <LocalVocabularyEntry>[];
    final starterList = <LocalVocabularyEntry>[];
    for (final row in rows) {
      final sourceKey = row['source_key']! as String;
      final sourceRow = row['source_row'];
      if (sourceRow is! int) continue;
      final entryProgress = progressById[row['id']];
      final entry = LocalVocabularyEntry(
        id: row['id']! as int,
        english: row['english']! as String,
        bisaya: row['bisaya']! as String,
        subanen: row['subanen']! as String,
        module: row['module']! as String,
        topic: row['topic']! as String,
        variety: row['variety']! as String,
        alternateForms: row['alternate_forms']! as String,
        source: row['source']! as String,
        reviewStatus: row['review_status']! as String,
        notes: row['notes']! as String,
        sourceFile: row['source_file']! as String,
        sourceRow: sourceRow,
        isLearned: entryProgress?['is_learned'] == 1,
        isBookmarked: entryProgress?['is_bookmarked'] == 1,
      );
      switch (sourceKey.split(':').first) {
        case 'vocabulary':
          vocabulary.add(entry);
        case 'still-needed':
          stillNeeded.add(entry);
        case 'starter-list':
          starterList.add(entry);
      }
    }

    final countRows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['vocabulary_source_row_counts_v1'],
      limit: 1,
    );
    final decodedCounts = countRows.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(countRows.single['value']! as String) as Map;
    return LocalVocabularyCatalog(
      vocabulary: vocabulary,
      starterList: starterList,
      stillNeeded: stillNeeded,
      sourceRowCounts: {
        'vocabulary': decodedCounts['vocabulary'] as int? ?? vocabulary.length,
        'still_needed':
            decodedCounts['still_needed'] as int? ?? stillNeeded.length,
        'starter_list':
            decodedCounts['starter_list'] as int? ?? starterList.length,
      },
    );
  }

  Future<Map<String, Object?>?> learner(String uid) async {
    final rows = await (await database).query(
      'learners',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> usernameAvailable(String username) async {
    final rows = await (await database).query(
      'learners',
      columns: ['uid'],
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username.trim()],
      limit: 1,
    );
    return rows.isEmpty;
  }

  Future<void> createLearner({
    required String uid,
    required String email,
    required String username,
    required String fullName,
    required String learningPreference,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (await database).transaction((txn) async {
      final existing = await txn.query(
        'learners',
        columns: ['uid'],
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('learners', {
          'uid': uid,
          'email': email,
          'username': username.trim(),
          'full_name': fullName.trim(),
          'learning_preference': learningPreference,
          'created_at': now,
          'last_login': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'learners',
          {'email': email, 'last_login': now, 'updated_at': now},
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }
      await _initializeLearnerProgress(txn, uid, now);
    });
  }

  Future<void> ensureLearner({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    final baseName = email.split('@').first.trim();
    final now = DateTime.now().toUtc().toIso8601String();
    await (await database).transaction((txn) async {
      final existing = await txn.query(
        'learners',
        columns: ['uid'],
        where: 'uid = ?',
        whereArgs: [uid],
        limit: 1,
      );
      if (existing.isEmpty) {
        var username = baseName.isEmpty ? uid : baseName;
        final duplicate = await txn.query(
          'learners',
          columns: ['uid'],
          where: 'username = ? COLLATE NOCASE',
          whereArgs: [username],
          limit: 1,
        );
        if (duplicate.isNotEmpty) username = 'learner_$uid';

        await txn.insert('learners', {
          'uid': uid,
          'email': email,
          'username': username,
          'full_name': fullName.trim().isEmpty ? username : fullName.trim(),
          'created_at': now,
          'last_login': now,
          'updated_at': now,
        });
      }
      await _initializeLearnerProgress(txn, uid, now);
    });
  }

  Future<void> _initializeLearnerProgress(
    DatabaseExecutor txn,
    String uid,
    String now,
  ) async {
    await txn.rawInsert(
      '''
      INSERT OR IGNORE INTO learning_progress (
        uid, module_id, last_lesson_index, updated_at
      )
      SELECT ?, id, NULL, ?
      FROM learning_modules
      WHERE is_published = 1
      ''',
      [uid, now],
    );
  }

  Future<void> recordLearnerLogin({
    required String uid,
    required String email,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{'last_login': now, 'updated_at': now};
    if (email.isNotEmpty) values['email'] = email;
    final updated = await (await database).update(
      'learners',
      values,
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (updated == 0) {
      throw StateError('Cannot record a login for a missing learner profile.');
    }
  }

  Future<void> importLegacyData(Map<String, dynamic> legacy) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final profiles = legacy['profiles'];
      if (profiles is Map) {
        for (final entry in profiles.entries) {
          if (entry.key is! String || entry.value is! Map) continue;
          final uid = entry.key as String;
          final profile = Map<String, dynamic>.from(entry.value as Map);
          final username = (profile['username'] as String? ?? '').trim();
          await txn.insert('learners', {
            'uid': uid,
            'email': profile['email'] as String? ?? '',
            'username': username.isEmpty ? 'legacy_${uid}_learner' : username,
            'full_name': profile['full_name'] as String? ?? username,
            'nickname': profile['nickname'],
            'avatar_id': profile['avatar_id'],
            'outfit_color': profile['outfit_color'],
            'avatar_completed': profile['avatar_completed'] == true ? 1 : 0,
            'learning_preference': profile['learning_preference'] ?? 'both',
            'xp': profile['xp'] is int ? profile['xp'] : 0,
            'created_at': now,
            'last_login': now,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      Future<void> ensureOwner(String uid) async {
        final rows = await txn.query(
          'learners',
          columns: ['uid'],
          where: 'uid = ?',
          whereArgs: [uid],
          limit: 1,
        );
        if (rows.isNotEmpty) return;
        await txn.insert('learners', {
          'uid': uid,
          'email': '',
          'username': 'legacy_${uid}_learner',
          'full_name': 'Learner',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final progressItems = legacy['progress'];
      if (progressItems is List) {
        for (final value in progressItems.whereType<Map>()) {
          final item = Map<String, dynamic>.from(value);
          final uid = item['uid'] as String?;
          final moduleId = item['module_id'] as int?;
          if (uid == null || moduleId == null) continue;
          final module = await txn.query(
            'learning_modules',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [moduleId],
            limit: 1,
          );
          if (module.isEmpty) continue;
          await ensureOwner(uid);
          await txn.insert('learning_progress', {
            'uid': uid,
            'module_id': moduleId,
            'last_lesson_index': item['last_lesson_index'],
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          final completed = item['completed_lesson_indices'];
          if (completed is List) {
            for (final index in completed.whereType<int>().toSet()) {
              await txn.insert('lesson_completions', {
                'uid': uid,
                'module_id': moduleId,
                'lesson_index': index,
                'completed_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
      }

      final completionItems = legacy['completions'];
      if (completionItems is List) {
        for (final value in completionItems.whereType<Map>()) {
          final item = Map<String, dynamic>.from(value);
          final uid = item['user_id'] as String? ?? 'legacy';
          final moduleId = item['module_id'] as int?;
          final lessonIndex = item['lesson_index'] as int?;
          if (moduleId == null || lessonIndex == null) continue;
          final module = await txn.query(
            'learning_modules',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [moduleId],
            limit: 1,
          );
          if (module.isEmpty) continue;
          await ensureOwner(uid);
          await txn.insert('lesson_completions', {
            'uid': uid,
            'module_id': moduleId,
            'lesson_index': lessonIndex,
            'completed_at': item['completed_at'] as String? ?? now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          final eventId = item['event_id'] as String?;
          if (eventId != null) {
            await txn.insert('learning_history', {
              'id': 'legacy:$eventId',
              'uid': uid,
              'event_type': 'lesson_completed',
              'entity_id': '$moduleId:$lessonIndex',
              'created_at': item['completed_at'] as String? ?? now,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }

      final searches = legacy['recent_searches'];
      if (searches is List) {
        for (final value in searches.whereType<Map>()) {
          final query = value['query'];
          if (query is! String || query.trim().isEmpty) continue;
          await ensureOwner('offline-guest');
          await txn.insert('dictionary_searches', {
            'uid': 'offline-guest',
            'query': query.trim(),
            'created_at': now,
          });
        }
      }
    });
  }

  Future<void> updateLearner(String uid, Map<String, Object?> values) async {
    await (await database).update(
      'learners',
      {...values, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<List<Map<String, Object?>>> modules({
    required String? uid,
    String search = '',
    bool includeUnpublished = false,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (!includeUnpublished) conditions.add('m.is_published = 1');
    if (search.trim().isNotEmpty) {
      conditions.add('(m.title LIKE ? OR m.description LIKE ?)');
      args
        ..add('%${search.trim()}%')
        ..add('%${search.trim()}%');
    }
    final rows = await db.query(
      'learning_modules m',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'm.id',
    );
    final result = <Map<String, Object?>>[];
    for (final row in rows) {
      result.add(await _moduleWithLessons(db, row, uid));
    }
    return result;
  }

  Future<Map<String, Object?>?> module(
    int moduleId, {
    required String? uid,
    bool includeUnpublished = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'learning_modules',
      where: includeUnpublished ? 'id = ?' : 'id = ? AND is_published = 1',
      whereArgs: [moduleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _moduleWithLessons(db, rows.first, uid);
  }

  Future<Map<String, Object?>> _moduleWithLessons(
    DatabaseExecutor db,
    Map<String, Object?> row,
    String? uid,
  ) async {
    final moduleId = row['id']! as int;
    final lessonRows = await db.query(
      'lessons',
      where: 'module_id = ?',
      whereArgs: [moduleId],
      orderBy: 'lesson_index',
    );
    final completions = uid == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'lesson_completions',
            columns: ['lesson_index'],
            where: 'uid = ? AND module_id = ?',
            whereArgs: [uid, moduleId],
          );
    final completed = completions.map((item) => item['lesson_index']).toSet();
    final progress = uid == null
        ? const <Map<String, Object?>>[]
        : await db.query(
            'learning_progress',
            columns: ['last_lesson_index'],
            where: 'uid = ? AND module_id = ?',
            whereArgs: [uid, moduleId],
            limit: 1,
          );
    final lessons = <Map<String, Object?>>[];
    for (final lesson in lessonRows) {
      final lessonId = lesson['id']! as int;
      final questions = await db.query(
        'quiz_questions',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        orderBy: 'position',
      );
      final quiz = <Map<String, Object?>>[];
      for (final question in questions) {
        final answers = await db.query(
          'quiz_answers',
          columns: ['answer_text'],
          where: 'question_id = ?',
          whereArgs: [question['id']],
          orderBy: 'position',
        );
        quiz.add({
          'question': question['question'],
          'choices': answers.map((item) => item['answer_text']).toList(),
          'correct_answer_index': question['correct_answer_index'],
          'explanation': question['explanation'],
        });
      }
      lessons.add({
        'index': lesson['lesson_index'],
        'title': lesson['title'],
        'content': lesson['content'],
        'completed': completed.contains(lesson['lesson_index']),
        'phrase': lesson['phrase'],
        'pronunciation': lesson['pronunciation'],
        'audio_url': lesson['audio_url'],
        'image_url': lesson['image_url'],
        'cultural_note': lesson['cultural_note'],
        'keywords': _decodeList(lesson['keywords_json'] as String?),
        'quiz': quiz,
      });
    }
    return {
      ...row,
      'lesson_count': lessons.length,
      'completed_lessons': completed.length,
      'last_lesson_index': progress.isEmpty
          ? null
          : progress.single['last_lesson_index'],
      'lessons': lessons,
    };
  }

  Future<int> saveModule(
    Map<String, dynamic> module, {
    int? moduleId,
    bool importIfMissing = false,
  }) async {
    final db = await database;
    return db.transaction(
      (txn) => _writeModule(
        txn,
        module,
        moduleId: moduleId,
        importIfMissing: importIfMissing,
      ),
    );
  }

  Future<int> seedBundledModule({
    required String key,
    required Map<String, dynamic> module,
  }) async {
    if (key.trim().isEmpty) {
      throw const FormatException('A bundled module key is required.');
    }
    final db = await database;
    return db.transaction((txn) async {
      final metadataKey = 'bundled_module:${key.trim()}';
      final markers = await txn.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [metadataKey],
        limit: 1,
      );
      if (markers.isNotEmpty) {
        final moduleId = int.tryParse(markers.single['value']! as String);
        if (moduleId == null) {
          throw const FormatException(
            'The bundled module installation marker is invalid.',
          );
        }
        return moduleId;
      }

      final moduleId = await _writeModule(txn, module);
      await txn.insert('app_metadata', {
        'key': metadataKey,
        'value': moduleId.toString(),
      });
      return moduleId;
    });
  }

  Future<int> _writeModule(
    DatabaseExecutor txn,
    Map<String, dynamic> module, {
    int? moduleId,
    bool importIfMissing = false,
  }) async {
    final title = module['title'];
    final description = module['description'] ?? '';
    final rawLessons = module['lessons'];
    if (title is! String || description is! String || rawLessons is! List) {
      throw const FormatException(
        'Module title, description, and lessons are required.',
      );
    }
    if (rawLessons.isEmpty) {
      throw const FormatException('A module must contain at least one lesson.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = moduleId == null
        ? const <Map<String, Object?>>[]
        : await txn.query(
            'learning_modules',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [moduleId],
            limit: 1,
          );
    final shouldInsert =
        moduleId == null || (importIfMissing && existing.isEmpty);
    final id = shouldInsert
        ? await txn.insert('learning_modules', {
            ...?(moduleId == null ? null : {'id': moduleId}),
            'title': title.trim(),
            'description': description.trim(),
            'is_published': module['is_published'] == true || importIfMissing
                ? 1
                : 0,
            'created_at': now,
            'updated_at': now,
          })
        : moduleId;
    if (moduleId != null && !shouldInsert) {
      final updated = await txn.update(
        'learning_modules',
        {
          'title': title.trim(),
          'description': description.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [moduleId],
      );
      if (updated == 0) throw const FormatException('Module not found.');
      await txn.delete('lessons', where: 'module_id = ?', whereArgs: [id]);
    }
    for (var index = 0; index < rawLessons.length; index++) {
      final lesson = Map<String, dynamic>.from(rawLessons[index] as Map);
      final quizQuestions = lesson['quiz'] as List? ?? const [];
      final lessonId = await txn.insert('lessons', {
        'module_id': id,
        'lesson_index': lesson['index'] is int ? lesson['index'] : index,
        'title': (lesson['title'] as String? ?? '').trim(),
        'content': (lesson['content'] as String? ?? '').trim(),
        'phrase': lesson['phrase'],
        'pronunciation': lesson['pronunciation'],
        'audio_url': lesson['audio_url'],
        'image_url': lesson['image_url'],
        'cultural_note': lesson['cultural_note'],
        'keywords_json': jsonEncode(lesson['keywords'] ?? const []),
      });
      for (var position = 0; position < quizQuestions.length; position++) {
        final question = Map<String, dynamic>.from(
          quizQuestions[position] as Map,
        );
        final choices = question['choices'] as List? ?? const [];
        final correct = question['correct_answer_index'];
        if (question['question'] is! String ||
            choices.length < 2 ||
            correct is! int ||
            correct < 0 ||
            correct >= choices.length) {
          throw const FormatException(
            'Quiz questions must have two or more choices and a valid answer.',
          );
        }
        final questionId = await txn.insert('quiz_questions', {
          'lesson_id': lessonId,
          'position': position,
          'question': question['question'],
          'correct_answer_index': correct,
          'explanation': question['explanation'],
        });
        for (var answerIndex = 0; answerIndex < choices.length; answerIndex++) {
          await txn.insert('quiz_answers', {
            'question_id': questionId,
            'position': answerIndex,
            'answer_text': choices[answerIndex] as String,
          });
        }
      }
    }
    return id;
  }

  Future<void> setModulePublished(int moduleId, bool published) async {
    final updated = await (await database).update(
      'learning_modules',
      {
        'is_published': published ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [moduleId],
    );
    if (updated == 0) throw const FormatException('Module not found.');
  }

  Future<void> deleteModule(int moduleId) async {
    await (await database).delete(
      'learning_modules',
      where: 'id = ?',
      whereArgs: [moduleId],
    );
  }

  Future<bool> startLesson(String uid, int moduleId, int lessonIndex) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await database;
    final lesson = await db.query(
      'lessons',
      columns: ['id'],
      where: 'module_id = ? AND lesson_index = ?',
      whereArgs: [moduleId, lessonIndex],
      limit: 1,
    );
    if (lesson.isEmpty) throw const FormatException('Lesson not found.');
    await db.insert('learning_progress', {
      'uid': uid,
      'module_id': moduleId,
      'last_lesson_index': lessonIndex,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<bool> completeLesson(String uid, int moduleId, int lessonIndex) async {
    final db = await database;
    return db.transaction((txn) async {
      final completion = await _recordLessonCompletion(
        txn,
        uid,
        moduleId,
        lessonIndex,
      );
      return completion.completed;
    });
  }

  Future<({bool completed, int xpAwarded})> _recordLessonCompletion(
    Transaction txn,
    String uid,
    int moduleId,
    int lessonIndex,
  ) async {
    final lessons = await txn.query(
      'lessons',
      columns: ['id'],
      where: 'module_id = ? AND lesson_index = ?',
      whereArgs: [moduleId, lessonIndex],
      limit: 1,
    );
    if (lessons.isEmpty) throw const FormatException('Lesson not found.');
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await txn.insert('lesson_completions', {
      'uid': uid,
      'module_id': moduleId,
      'lesson_index': lessonIndex,
      'completed_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert('learning_progress', {
      'uid': uid,
      'module_id': moduleId,
      'last_lesson_index': lessonIndex,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (inserted == 0) return (completed: false, xpAwarded: 0);

    var earnedXp = 10;
    if (await _count(
          txn,
          'SELECT COUNT(*) AS count FROM lesson_completions WHERE uid = ? AND substr(completed_at, 1, 10) = ?',
          [uid, now.substring(0, 10)],
        ) ==
        1) {
      earnedXp += 5;
      await txn.insert('learning_history', {
        'id': '${uid}_daily_$now',
        'uid': uid,
        'event_type': 'daily_bonus_awarded',
        'entity_id': now.substring(0, 10),
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final current = DateTime.parse(now);
    final weekStart = DateTime.utc(
      current.year,
      current.month,
      current.day - (current.weekday - 1),
    ).toIso8601String();
    if (await _count(
          txn,
          'SELECT COUNT(*) AS count FROM lesson_completions WHERE uid = ? AND completed_at >= ?',
          [uid, weekStart],
        ) ==
        5) {
      earnedXp += 25;
      await txn.insert('learning_history', {
        'id': '${uid}_weekly_$weekStart',
        'uid': uid,
        'event_type': 'weekly_bonus_awarded',
        'entity_id': weekStart.substring(0, 10),
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await txn.rawUpdate(
      'UPDATE learners SET xp = xp + ?, updated_at = ? WHERE uid = ?',
      [earnedXp, now, uid],
    );
    await txn.insert('learning_history', {
      'id': '${uid}_${moduleId}_${lessonIndex}_$now',
      'uid': uid,
      'event_type': 'lesson_completed',
      'entity_id': '$moduleId:$lessonIndex',
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return (completed: true, xpAwarded: earnedXp);
  }

  Future<Map<String, Object?>?> moduleProgress(String uid, int moduleId) async {
    final rows = await (await database).query(
      'learning_progress',
      where: 'uid = ? AND module_id = ?',
      whereArgs: [uid, moduleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final completed = await (await database).query(
      'lesson_completions',
      columns: ['lesson_index'],
      where: 'uid = ? AND module_id = ?',
      whereArgs: [uid, moduleId],
      orderBy: 'lesson_index',
    );
    return {
      'last_lesson_index': rows.single['last_lesson_index'],
      'completed_lesson_indices': completed
          .map((item) => item['lesson_index'])
          .toList(),
    };
  }

  Future<Map<String, Object?>> submitQuiz(
    String uid,
    int moduleId,
    int lessonIndex,
    List<int> answers,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final lessonRows = await txn.query(
        'lessons',
        columns: ['id'],
        where: 'module_id = ? AND lesson_index = ?',
        whereArgs: [moduleId, lessonIndex],
        limit: 1,
      );
      if (lessonRows.isEmpty) throw const FormatException('Lesson not found.');
      final lessonId = lessonRows.single['id']! as int;
      final questions = await txn.query(
        'quiz_questions',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
        orderBy: 'position',
      );
      if (questions.isEmpty) {
        throw const FormatException('This lesson has no quiz questions.');
      }
      if (answers.length != questions.length) {
        throw const FormatException(
          'Answer every quiz question before submitting.',
        );
      }
      final resultQuestions = <Map<String, dynamic>>[];
      var correctAnswers = 0;
      for (var index = 0; index < questions.length; index++) {
        final question = questions[index];
        final choices = await txn.query(
          'quiz_answers',
          columns: ['answer_text'],
          where: 'question_id = ?',
          whereArgs: [question['id']],
          orderBy: 'position',
        );
        final choiceList = choices
            .map((item) => item['answer_text'] as String)
            .toList();
        final correct = question['correct_answer_index']! as int;
        if (answers[index] < 0 || answers[index] >= choiceList.length) {
          throw const FormatException('A selected quiz answer is invalid.');
        }
        if (answers[index] == correct) correctAnswers++;
        resultQuestions.add({
          'question': question['question'],
          'choices': choiceList,
          'selected_answer_index': answers[index],
          'correct_answer_index': correct,
          'explanation': question['explanation'],
        });
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final previous = await txn.rawQuery(
        'SELECT MAX(score) AS best FROM quiz_results WHERE uid = ? AND module_id = ? AND lesson_index = ?',
        [uid, moduleId, lessonIndex],
      );
      final score = (100 * correctAnswers / questions.length).round();
      final completion = await _recordLessonCompletion(
        txn,
        uid,
        moduleId,
        lessonIndex,
      );
      final xpAwarded = score > ((previous.first['best'] as int?) ?? -1)
          ? correctAnswers
          : 0;
      if (xpAwarded > 0) {
        await txn.rawUpdate(
          'UPDATE learners SET xp = xp + ?, updated_at = ? WHERE uid = ?',
          [xpAwarded, now, uid],
        );
      }
      final resultId = await txn.insert('quiz_results', {
        'uid': uid,
        'module_id': moduleId,
        'lesson_index': lessonIndex,
        'score': score,
        'total_questions': questions.length,
        'correct_answers': correctAnswers,
        'answers_json': jsonEncode(resultQuestions),
        'completed_at': now,
      });
      await txn.insert('learning_history', {
        'id': '${uid}_quiz_$resultId',
        'uid': uid,
        'event_type': 'quiz_completed',
        'entity_id': '$moduleId:$lessonIndex',
        'event_data_json': jsonEncode({'score': score, 'result_id': resultId}),
        'created_at': now,
      });
      return {
        'attempt_id': resultId,
        'score': score,
        'total_questions': questions.length,
        'correct_answers': correctAnswers,
        'incorrect_answers': questions.length - correctAnswers,
        'xp_awarded': xpAwarded,
        'lesson_xp_awarded': completion.xpAwarded,
        'total_xp_awarded': completion.xpAwarded + xpAwarded,
        'completed_at': now,
        'questions': resultQuestions,
      };
    });
  }

  Future<List<Map<String, Object?>>> vocabulary({String query = ''}) async {
    final normalized = query.trim();
    return (await database).query(
      'vocabulary',
      where: normalized.isEmpty ? null : 'english LIKE ? OR bisaya LIKE ? OR subanen LIKE ? OR alternate_forms LIKE ?',
      whereArgs: normalized.isEmpty ? null : List.filled(4, '%$normalized%'),
      orderBy: 'source_file, source_row, id',
    );
  }

  Future<void> setVocabularyProgress({
    required String uid,
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  }) async {
    await (await database).insert('vocabulary_progress', {
      'uid': uid,
      'vocabulary_id': vocabularyId,
      'is_learned': learned ? 1 : 0,
      'is_bookmarked': bookmarked ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> vocabularyProgress(String uid) async =>
      (await database).query(
        'vocabulary_progress',
        where: 'uid = ?',
        whereArgs: [uid],
        orderBy: 'vocabulary_id',
      );

  Future<List<Map<String, Object?>>> quizAttempts(
    String uid,
    int moduleId,
    int lessonIndex,
  ) async {
    final rows = await (await database).query(
      'quiz_results',
      where: 'uid = ? AND module_id = ? AND lesson_index = ?',
      whereArgs: [uid, moduleId, lessonIndex],
      orderBy: 'completed_at DESC',
    );
    return rows
        .map(
          (row) => {
            'attempt_id': row['id'],
            'score': row['score'],
            'total_questions': row['total_questions'],
            'correct_answers': row['correct_answers'],
            'incorrect_answers':
                (row['total_questions']! as int) -
                (row['correct_answers']! as int),
            'completed_at': row['completed_at'],
            'questions': _decodeList(row['answers_json'] as String),
          },
        )
        .toList();
  }

  Future<void> addHistory({
    required String id,
    required String? uid,
    required String eventType,
    String? entityId,
    Map<String, dynamic> eventData = const {},
  }) async {
    await (await database).insert('learning_history', {
      'id': id,
      'uid': uid,
      'event_type': eventType,
      'entity_id': entityId,
      'event_data_json': jsonEncode(eventData),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> historyEvents({
    required String uid,
    required String eventType,
  }) async {
    final rows = await (await database).query(
      'learning_history',
      where: 'uid = ? AND event_type = ?',
      whereArgs: [uid, eventType],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => {
            'id': row['id'],
            'created_at': row['created_at'],
            'event_data': jsonDecode(row['event_data_json']! as String),
          },
        )
        .toList();
  }

  Future<void> savePack(Map<String, dynamic> pack) async {
    final id = pack['id'];
    final type = pack['type'];
    final title = pack['title'];
    final data = pack['data'];
    final media = pack['media'] ?? <String, String>{};
    if (id is! String ||
        type is! String ||
        title is! String ||
        data == null ||
        media is! Map) {
      throw const FormatException('Offline content pack is incomplete.');
    }
    final dataJson = jsonEncode(data);
    final mediaJson = jsonEncode(media);
    await (await database).insert('content_packs', {
      'id': id,
      'type': type,
      'title': title,
      'size_bytes':
          utf8.encode(dataJson).length + utf8.encode(mediaJson).length,
      'data_json': dataJson,
      'media_json': mediaJson,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> packs() async {
    final rows = await (await database).query(
      'content_packs',
      orderBy: 'title',
    );
    return rows.map((row) {
      return {
        'id': row['id'],
        'type': row['type'],
        'title': row['title'],
        'size_bytes': row['size_bytes'],
        'downloaded_at': row['downloaded_at'],
        'data': jsonDecode(row['data_json']! as String),
        'media': jsonDecode(row['media_json']! as String),
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> pack(String id) async {
    final rows = await (await database).query(
      'content_packs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return {
      'id': row['id'],
      'type': row['type'],
      'title': row['title'],
      'size_bytes': row['size_bytes'],
      'downloaded_at': row['downloaded_at'],
      'data': jsonDecode(row['data_json']! as String),
      'media': jsonDecode(row['media_json']! as String),
    };
  }

  Future<void> removePack(String id) async {
    await (await database).delete(
      'content_packs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addRecentSearch(String uid, String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final db = await database;
    await db.delete(
      'dictionary_searches',
      where: 'uid = ? AND query = ? COLLATE NOCASE',
      whereArgs: [uid, normalized],
    );
    await db.insert('dictionary_searches', {
      'uid': uid,
      'query': normalized,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await db.rawDelete(
      'DELETE FROM dictionary_searches WHERE uid = ? AND id NOT IN (SELECT id FROM dictionary_searches WHERE uid = ? ORDER BY id DESC LIMIT 10)',
      [uid, uid],
    );
  }

  Future<List<String>> recentSearches(String uid) async {
    final rows = await (await database).query(
      'dictionary_searches',
      columns: ['query'],
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'id DESC',
      limit: 10,
    );
    return rows.map((item) => item['query']! as String).toList();
  }

  Future<List<Map<String, Object?>>> searchVerifiedVocabulary({
    required String column,
    required String query,
  }) async {
    const columns = {'subanen', 'english', 'bisaya'};
    if (!columns.contains(column)) throw ArgumentError.value(column, 'column');
    return (await database).rawQuery(
      'SELECT * FROM vocabulary WHERE is_active = 1 AND is_verified = 1 AND $column LIKE ? COLLATE NOCASE ORDER BY $column LIMIT 50',
      ['%${query.trim()}%'],
    );
  }

  Future<List<Map<String, Object?>>> adminVocabulary({
    String query = '',
  }) async {
    final value = '%${query.trim()}%';
    return (await database).query(
      'vocabulary',
      where: query.trim().isEmpty
          ? null
          : 'subanen LIKE ? OR english LIKE ? OR bisaya LIKE ?',
      whereArgs: query.trim().isEmpty ? null : [value, value, value],
      orderBy: 'source_file, source_row, id',
      limit: 500,
    );
  }

  Future<int> saveVocabulary(Map<String, dynamic> entry, {int? entryId}) async {
    final row = <String, Object?>{
      'source_key': entryId == null
          ? 'admin:${const Uuid().v4()}'
          : 'admin:$entryId',
      'source_file': entry['source'] ?? 'LearnLite local entry',
      'english': entry['english_translation'] ?? '',
      'bisaya': entry['bisaya_translation'] ?? '',
      'subanen': entry['subanen_word'] ?? '',
      'module': entry['module'] ?? '',
      'topic': entry['topic'] ?? '',
      'pronunciation': entry['pronunciation'],
      'audio_url': entry['audio_url'],
      'source': entry['source'] ?? '',
      'review_status': entry['review_status'] ?? 'Pending review',
      'is_verified': entry['is_verified'] == true ? 1 : 0,
      'is_active': entry['is_active'] == false ? 0 : 1,
    };
    final db = await database;
    if (entryId == null) return db.insert('vocabulary', row);
    await db.update('vocabulary', row, where: 'id = ?', whereArgs: [entryId]);
    return entryId;
  }

  Future<void> deactivateVocabulary(int entryId) async {
    await (await database).update(
      'vocabulary',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> _count(
    DatabaseExecutor db,
    String sql,
    List<Object?> args,
  ) async => (await db.rawQuery(sql, args)).single['count']! as int;

  Future<void> saveResource({
    required String id,
    required String name,
    required String mediaType,
    required List<int> bytes,
    int? moduleId,
    int? lessonIndex,
    int? vocabularyId,
  }) async {
    await (await database).insert('local_resources', {
      'id': id,
      'name': name,
      'media_type': mediaType,
      'size_bytes': bytes.length,
      'module_id': moduleId,
      'lesson_index': lessonIndex,
      'vocabulary_id': vocabularyId,
      'bytes': bytes,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> resources() async =>
      (await database).query('local_resources', orderBy: 'created_at DESC');

  Future<List<int>?> resourceBytes(String id) async {
    final rows = await (await database).query(
      'local_resources',
      columns: ['bytes'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.single['bytes']! as List<int>);
  }

  Future<int> storedBytes() async {
    final rows = await (await database).rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) AS size FROM content_packs',
    );
    return rows.single['size']! as int;
  }

  List<dynamic> _decodeList(String? json) {
    if (json == null) return const [];
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Saved learning data is invalid.');
    }
    return decoded;
  }
}
