import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        kReleaseMode,
        TargetPlatform;
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/bundled_learning_content.dart';
import '../../core/learning_database.dart';
import '../../core/local_day.dart';
import '../../core/offline_content_store.dart';
import '../../firebase_options.dart';
import '../content/content_gateway.dart';
import '../content/local_vocabulary.dart';
import '../tutor/tutor_gateway.dart';
import 'auth_models.dart';

export 'auth_models.dart';

class FirebaseAuthGateway
    implements
        AuthGateway,
        DictionaryGateway,
        OfflineSyncStatusGateway,
        AdminGateway,
        TutorTokenProvider {
  FirebaseAuthGateway({
    this.firebaseAuth,
    LearningDatabase? database,
    this.initializationError,
  }) : _database = database ?? LearningDatabase.instance,
       super();

  final FirebaseAuth? firebaseAuth;
  final LearningDatabase _database;

  String? get currentEmail => firebaseAuth?.currentUser?.email;

  @override
  final String? initializationError;

  @override
  Future<String?> tutorIdToken() async {
    final user = firebaseAuth?.currentUser;
    if (user == null) {
      throw const AuthFailure('Sign in to use the AI Tutor.');
    }
    if (!user.emailVerified) {
      throw const AuthFailure('Verify your email before using the AI Tutor.');
    }
    try {
      return await user.getIdToken();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _firebaseErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    }
  }

  static Future<AuthGateway> initialize() async {
    if (kIsWeb) {
      return const UnavailableAuthGateway();
    }

    // Startup timing (debug and profile builds only) so slow steps are
    // measured rather than guessed.
    final timer = _StartupTimer();
    final database = LearningDatabase.instance;
    await database.database;
    timer.lap('open database');
    await database.seedVocabularyIfChanged(LocalVocabularyRepository());
    timer.lap('vocabulary seed check');
    await _migrateLegacyCache(database, OfflineContentStore());
    timer.lap('legacy cache check');
    await database.seedBundledModule(
      key: bundledOfflineModuleKey,
      module: bundledOfflineModule,
    );
    timer.lap('bundled module');

    FirebaseAuth? auth;
    String? authError;
    try {
      if (Firebase.apps.isNotEmpty) {
        final app = Firebase.app();
        if (!FirebaseOptionsConfig.matches(app.options)) {
          authError = 'Firebase is connected to a different project. Check the LearnLite Firebase configuration.';
        } else {
          auth = FirebaseAuth.instanceFor(app: app);
        }
      } else if (FirebaseOptionsConfig.isConfigured) {
        await Firebase.initializeApp(options: FirebaseOptionsConfig.current);
        auth = FirebaseAuth.instance;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
        auth = FirebaseAuth.instance;
      } else {
        authError = FirebaseOptionsConfig.configurationError;
      }
    } on FirebaseException catch (error) {
      authError =
          'Firebase initialization failed (${error.code}). Check the LearnLite Firebase options and Android package registration.';
    }
    timer
      ..lap('firebase init')
      ..report();

    return FirebaseAuthGateway(
      firebaseAuth: auth,
      database: database,
      initializationError: authError,
    );
  }

  @override
  Future<VocabularyQuizAttempt> saveVocabularyQuizAttempt({
    required String category,
    required List<VocabularyQuizResponse> responses,
  }) async {
    if (responses.isEmpty) {
      throw const AuthFailure('A vocabulary quiz must contain answers.');
    }
    final uid = await _ownerUid();
    final attempt = VocabularyQuizAttempt(
      id: const Uuid().v4(),
      category: category,
      completedAt: DateTime.now().toUtc(),
      responses: List.unmodifiable(responses),
    );
    await _database.addHistory(
      id: '${uid}_vocabulary_quiz_${attempt.id}',
      uid: uid,
      eventType: 'vocabulary_quiz_completed',
      entityId: category,
      eventData: attempt.toHistoryJson(),
    );
    return attempt;
  }

  @override
  Future<List<VocabularyQuizAttempt>> fetchVocabularyQuizAttempts() async {
    final rows = await _database.historyEvents(
      uid: await _ownerUid(),
      eventType: 'vocabulary_quiz_completed',
    );
    return rows.map(VocabularyQuizAttempt.fromHistory).toList();
  }

  static Future<void> _migrateLegacyCache(
    LearningDatabase database,
    OfflineContentStore oldStore,
  ) async {
    const migrationKey = 'legacy_shared_preferences_import_v1';
    final db = await database.database;
    final markers = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [migrationKey],
      limit: 1,
    );
    if (markers.isNotEmpty) return;

    final legacy = await oldStore.exportLegacyData();
    final packs = legacy['packs'];
    if (packs is List) {
      for (final value in packs.whereType<Map>()) {
        final pack = Map<String, dynamic>.from(value);
        await database.savePack(pack);
        final packId = pack['id'];
        final data = pack['data'];
        if (packId is String &&
            packId.startsWith('module:') &&
            data is Map<String, dynamic>) {
          final moduleId = int.tryParse(packId.substring('module:'.length));
          if (moduleId != null) {
            await database.saveModule(
              Map<String, dynamic>.from(data)..['is_published'] = true,
              moduleId: moduleId,
              importIfMissing: true,
            );
          }
        }
      }
    }
    await database.importLegacyData(legacy);

    await db.insert('app_metadata', {
      'key': migrationKey,
      'value': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  bool get isConfigured => firebaseAuth != null;

  @override
  Stream<AuthSession?> get authStateChanges {
    final auth = firebaseAuth;
    if (auth == null) return Stream<AuthSession?>.value(null);
    return auth.idTokenChanges().map(
      (user) => user == null
          ? null
          : AuthSession(
              user.uid,
              email: user.email,
              emailVerified: user.emailVerified,
            ),
    );
  }

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _database.usernameAvailable(username);

  @override
  Future<LearnerProfile> fetchProfile() async {
    final user = _requireUser();
    await _database.ensureLearner(
      uid: user.uid,
      email: user.email ?? '',
      fullName: user.displayName ?? '',
    );
    await _database.recordLearnerLogin(uid: user.uid, email: user.email ?? '');
    final row = await _database.learner(user.uid);
    if (row == null) {
      throw const AuthFailure(
        'Your local learner profile could not be loaded.',
      );
    }
    return _profileFromRow(row, user.uid);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    final user = _requireUser();
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthFailure('This account does not have an email address.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential' ||
          error.code == 'invalid-login-credentials') {
        throw const AuthFailure('Your current password is incorrect.');
      }
      throw AuthFailure(
        _firebaseErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    }
  }

  Future<LearnerProfile> _profileFromRow(
    Map<String, Object?> row,
    String uid,
  ) async {
    final db = await _database.database;
    final completions = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM lesson_completions WHERE uid = ?',
      [uid],
    );
    final streak = await _currentStreak(uid);
    return LearnerProfile.fromJson({
      'username': row['username'],
      'full_name': row['full_name'],
      'nickname': row['nickname'],
      'avatar_id': row['avatar_id'],
      'outfit_color': row['outfit_color'],
      'avatar_completed': row['avatar_completed'] == 1,
      'user_level': ((row['xp'] as int? ?? 0) ~/ 100) + 1,
      'xp': row['xp'] ?? 0,
      'streak': streak,
      'completed_lessons': completions.single['count'] ?? 0,
    });
  }

  @override
  Future<LearnerProfile> updateAvatarProfile(LearnerProfile profile) async {
    final user = _requireUser();
    final fullName = profile.fullName.trim();
    if (fullName.isEmpty || fullName.length > 80) {
      throw const AuthFailure('Name must be between 1 and 80 characters.');
    }
    final existing = await _database.learner(user.uid);
    if (existing == null) {
      throw const AuthFailure('Your learner profile could not be loaded.');
    }
    if (existing['full_name'] != fullName) {
      try {
        await user.updateDisplayName(fullName);
      } on FirebaseAuthException catch (error) {
        throw AuthFailure(
          _firebaseErrorMessage(error.code),
          isOffline: error.code == 'network-request-failed',
        );
      }
    }
    await _database.updateLearner(user.uid, {
      'full_name': fullName,
      'nickname': profile.nickname,
      'avatar_id': profile.avatarId,
      'outfit_color': profile.outfitColor,
      'avatar_completed': profile.avatarCompleted ? 1 : 0,
    });
    final row = await _database.learner(user.uid);
    if (row == null) {
      throw const AuthFailure('Your learner profile could not be saved.');
    }
    return _profileFromRow(row, user.uid);
  }

  @override
  Future<List<LearningModule>> fetchModules({String search = ''}) async {
    final uid = await _ownerUid();
    final modules = await _database.modules(uid: uid, search: search);
    return modules.map(LearningModule.fromJson).toList();
  }

  @override
  Future<LearningModule> fetchModule(int moduleId) async {
    final data = await _database.module(moduleId, uid: await _ownerUid());
    if (data == null) {
      throw const AuthFailure('This module is not available on this device.');
    }
    return LearningModule.fromJson(data);
  }

  @override
  Future<LearningModule> startModuleLesson(
    int moduleId,
    int lessonIndex,
  ) async {
    final uid = await _ownerUid();
    await _database.startLesson(uid, moduleId, lessonIndex);
    return fetchModule(moduleId);
  }

  @override
  Future<LearningModule> completeModuleLesson(
    int moduleId,
    int lessonIndex,
  ) async {
    final uid = await _ownerUid();
    await _database.completeLesson(uid, moduleId, lessonIndex);
    return fetchModule(moduleId);
  }

  @override
  Future<QuizResult> submitLessonQuiz(
    int moduleId,
    int lessonIndex,
    List<int> answers,
  ) async {
    final result = await _database.submitQuiz(
      await _ownerUid(),
      moduleId,
      lessonIndex,
      answers,
    );
    return QuizResult.fromJson(result);
  }

  @override
  Future<List<QuizResult>> fetchLessonQuizAttempts(
    int moduleId,
    int lessonIndex,
  ) async {
    final results = await _database.quizAttempts(
      await _ownerUid(),
      moduleId,
      lessonIndex,
    );
    return results.map(QuizResult.fromJson).toList();
  }

  @override
  Future<RewardsOverview> fetchRewards() async {
    final uid = await _ownerUid();
    final db = await _database.database;
    // Rewards follow the learner's local calendar day (stored times are UTC).
    final now = _database.clock();
    final today = localCalendarDate(now);
    final todayKey = dateKeyOf(today);
    final localWeek = localWeekStart(now);
    final weekStart = DateTime.utc(
      localWeek.year,
      localWeek.month,
      localWeek.day,
    );
    final completions = await db.query(
      'lesson_completions',
      columns: ['completed_at'],
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'completed_at DESC',
    );
    final completionTimes = completions
        .map((row) => DateTime.parse(row['completed_at']! as String))
        .toList();
    final activeDates = completionTimes.map(localCalendarDate).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final todayLessons = completionTimes
        .where((time) => localDateKey(time) == todayKey)
        .length;
    final thisWeekLessons = completionTimes
        .where((time) => !time.isBefore(localWeek))
        .length;
    final streak = await _currentStreak(uid);
    final longestStreak = _longestStreak(activeDates);
    final calendar = List.generate(7, (index) {
      final date = DateTime.utc(today.year, today.month, today.day - 6 + index);
      return RewardCalendarDay(
        date: date,
        weekday: _weekday(date.weekday),
        active: activeDates.contains(date),
        isToday: dateKeyOf(date) == todayKey,
        isFuture: date.isAfter(today),
      );
    });
    final badges = [
      _badge(
        id: 'first-lesson',
        title: 'First Steps',
        description: 'Complete your first lesson.',
        progress: completions.length,
        target: 1,
      ),
      _badge(
        id: 'five-lessons',
        title: 'Dedicated Learner',
        description: 'Complete five lessons.',
        progress: completions.length,
        target: 5,
      ),
      _badge(
        id: 'perfect-quiz',
        title: 'Perfect Score',
        description: 'Earn a perfect quiz score.',
        progress: await _hasPerfectQuiz(uid) ? 1 : 0,
        target: 1,
      ),
      _badge(
        id: 'seven-day-streak',
        title: 'Weekly Streak',
        description: 'Learn seven days in a row.',
        progress: streak,
        target: 7,
      ),
    ];
    final certificates = await _completedCertificates(uid);
    return RewardsOverview(
      timezone: now.timeZoneName,
      today: today,
      streak: streak,
      longestStreak: longestStreak,
      activeDates: activeDates,
      calendar: calendar,
      dailyQuest: DailyQuestStatus(
        title: 'Daily learning',
        description: 'Complete one lesson today.',
        progress: todayLessons.clamp(0, 1),
        target: 1,
        completed: todayLessons > 0,
        xpReward: 5,
        xpAwarded: await _hasHistoryEvent(uid, 'daily_bonus_awarded', todayKey)
            ? 5
            : 0,
      ),
      weeklyChest: WeeklyChestStatus(
        title: 'Weekly chest',
        description: 'Complete five lessons this week.',
        progress: thisWeekLessons.clamp(0, 5),
        target: 5,
        unlocked: thisWeekLessons >= 5,
        xpReward: 25,
        xpAwarded:
            await _hasHistoryEvent(
              uid,
              'weekly_bonus_awarded',
              dateKeyOf(weekStart),
            )
            ? 25
            : 0,
        weekStart: weekStart,
      ),
      badges: badges,
      certificates: certificates,
    );
  }

  @override
  Future<Uint8List> fetchCertificatePdf(String certificateId) async {
    final uid = await _ownerUid();
    final certificates = await _completedCertificates(uid);
    final certificate = certificates.where(
      (item) => item.certificateId == certificateId,
    );
    if (certificate.isEmpty) {
      throw const AuthFailure('This certificate is not available locally.');
    }
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('LearnLite', style: pw.TextStyle(fontSize: 28)),
              pw.SizedBox(height: 32),
              pw.Text('Certificate of Completion'),
              pw.SizedBox(height: 20),
              pw.Text(
                certificate.single.learnerName,
                style: pw.TextStyle(fontSize: 24),
              ),
              pw.SizedBox(height: 12),
              pw.Text('completed ${certificate.single.moduleTitle}'),
              pw.SizedBox(height: 28),
              pw.Text(localDateKey(certificate.single.issuedAt)),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  @override
  Future<List<DictionaryTranslation>> searchDictionary(
    String query, {
    String sourceLanguage = 'Subanen',
    String targetLanguage = 'English',
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final sourceColumn = _languageColumn(sourceLanguage);
    final targetColumn = _languageColumn(targetLanguage);
    final rows = await _database.searchVocabulary(
      column: sourceColumn,
      query: normalized,
    );
    return rows
        .where((row) => (row[targetColumn] as String? ?? '').isNotEmpty)
        .map((row) {
          final entry = DictionaryEntry.fromJson({
            'id': row['id'],
            'subanen_word': row['subanen'],
            'english_translation': row['english'],
            'bisaya_translation': row['bisaya'],
            'pronunciation': row['pronunciation'],
            'audio_url': row['audio_url'],
            'module': row['module'],
            'topic': row['topic'],
            'source': row['source'],
            'review_status': row['review_status'],
            'is_verified': row['is_verified'] == 1,
          });
          return DictionaryTranslation(
            entry: entry,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            translation: row[targetColumn]! as String,
          );
        })
        .toList();
  }

  @override
  Future<LocalVocabularyCatalog> localVocabulary() async =>
      _database.vocabularyCatalog(uid: await _ownerUid());

  @override
  Future<void> setVocabularyLearningStatus({
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  }) async {
    await _database.setVocabularyProgress(
      uid: await _ownerUid(),
      vocabularyId: vocabularyId,
      learned: learned,
      bookmarked: bookmarked,
    );
  }

  @override
  Future<List<String>> recentDictionarySearches() async =>
      _database.recentSearches(await _ownerUid());

  @override
  Future<void> recordDictionarySearch(String query) async {
    await _database.addRecentSearch(await _ownerUid(), query);
  }

  @override
  Future<List<ContentPackDescriptor>> availableContentPacks() async {
    final packs = await downloadedContentPacks();
    final downloadedIds = packs.map((item) => item.id).toSet();
    final modules = await _database.modules(uid: null);
    return [
      ...modules.map((module) {
        final id = 'module:${module['id']}';
        return ContentPackDescriptor(
          id: id,
          type: 'module',
          title: module['title']! as String,
          sizeBytes: utf8.encode(jsonEncode(module)).length,
          downloaded: downloadedIds.contains(id),
        );
      }),
      ...packs.where(
        (pack) => !modules.any((module) => pack.id == 'module:${module['id']}'),
      ),
    ];
  }

  @override
  Future<void> downloadContentPack(String id) async {
    if (id == 'dictionary') {
      final entries = await _database.adminVocabulary();
      final verified = entries
          .where((row) => row['is_verified'] == 1 && row['is_active'] == 1)
          .map(_dictionaryJson)
          .toList();
      if (verified.isEmpty) {
        throw const AuthFailure(
          'There is no verified dictionary content to download.',
        );
      }
      await _database.savePack({
        'id': id,
        'type': 'dictionary',
        'title': 'Verified dictionary',
        'data': verified,
        'media': <String, String>{},
      });
      return;
    }
    if (!id.startsWith('module:')) {
      throw const AuthFailure('This content pack is not available.');
    }
    final moduleId = int.tryParse(id.substring('module:'.length));
    if (moduleId == null) throw const AuthFailure('This module ID is invalid.');
    final module = await _database.module(moduleId, uid: null);
    if (module == null) {
      throw const AuthFailure('This module is not available on this device.');
    }
    await _database.savePack({
      'id': id,
      'type': 'module',
      'title': module['title'],
      'data': module,
      'media': <String, String>{},
    });
  }

  @override
  Future<void> removeContentPack(String id) => _database.removePack(id);

  @override
  Future<List<ContentPackDescriptor>> downloadedContentPacks() async =>
      (await _database.packs())
          .map((pack) => ContentPackDescriptor.fromJson(pack, downloaded: true))
          .toList();

  @override
  Future<int> offlineStorageBytes() => _database.storedBytes();

  @override
  Future<String?> offlineSyncNotice() async => null;

  @override
  Future<Uint8List?> cachedResource(String path) async {
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'local' && uri?.host == 'resource') {
      final bytes = await _database.resourceBytes(uri!.pathSegments.last);
      return bytes == null ? null : Uint8List.fromList(bytes);
    }
    for (final pack in await _database.packs()) {
      final media = pack['media'];
      if (media is Map && media[path] is String) {
        return base64Decode(media[path] as String);
      }
    }
    return null;
  }

  @override
  Future<Uint8List> fetchResourceBytes(String path) async {
    final cached = await cachedResource(path);
    if (cached != null) return cached;
    throw const AuthFailure('This resource has not been saved on this device.');
  }

  @override
  Future<void> verifyAdministrator() async {
    final user = _requireUser();
    try {
      final claims = (await user.getIdTokenResult()).claims ?? const {};
      final roles = claims['roles'];
      final isAdmin =
          claims['admin'] == true ||
          claims['role'] == 'admin' ||
          (roles is List && roles.contains('admin'));
      if (!isAdmin) {
        throw const AuthFailure(
          'Administrator access is not enabled for this Firebase account.',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseErrorMessage(error.code));
    }
  }

  @override
  Future<AdminDashboardSummary> fetchAdminSummary() async {
    await verifyAdministrator();
    final db = await _database.database;
    Future<int> count(String sql) async =>
        (await db.rawQuery(sql)).single['count']! as int;
    final recent = await db.query(
      'local_resources',
      orderBy: 'created_at DESC',
      limit: 5,
    );
    final activity = await db.query(
      'learning_history',
      orderBy: 'created_at DESC',
      limit: 10,
    );
    return AdminDashboardSummary(
      totalModules: await count(
        'SELECT COUNT(*) AS count FROM learning_modules',
      ),
      publishedModules: await count(
        'SELECT COUNT(*) AS count FROM learning_modules WHERE is_published = 1',
      ),
      totalLessons: await count('SELECT COUNT(*) AS count FROM lessons'),
      verifiedDictionaryEntries: await count(
        'SELECT COUNT(*) AS count FROM vocabulary WHERE is_verified = 1 AND is_active = 1',
      ),
      uploadedResources: await count(
        'SELECT COUNT(*) AS count FROM local_resources',
      ),
      quizAttempts: await count('SELECT COUNT(*) AS count FROM quiz_results'),
      recentUploads: recent.map(_resourceFromRow).toList(),
      activity: activity.map((row) => Map<String, dynamic>.from(row)).toList(),
    );
  }

  @override
  Future<List<AdminModule>> fetchAdminModules() async {
    await verifyAdministrator();
    return (await _database.modules(uid: null, includeUnpublished: true))
        .map(
          (module) => AdminModule.fromJson({
            ...module,
            'is_published': module['is_published'] == 1,
          }),
        )
        .toList();
  }

  @override
  Future<AdminModule> createAdminModule(Map<String, dynamic> module) async {
    await verifyAdministrator();
    final id = await _database.saveModule(module);
    return _adminModule(id);
  }

  @override
  Future<AdminModule> updateAdminModule(
    int moduleId,
    Map<String, dynamic> module,
  ) async {
    await verifyAdministrator();
    await _database.saveModule(module, moduleId: moduleId);
    return _adminModule(moduleId);
  }

  Future<AdminModule> _adminModule(int moduleId) async {
    final module = await _database.module(
      moduleId,
      uid: null,
      includeUnpublished: true,
    );
    if (module == null) throw const AuthFailure('Module not found.');
    return AdminModule.fromJson({
      ...module,
      'is_published': module['is_published'] == 1,
    });
  }

  @override
  Future<void> setModulePublished(int moduleId, bool isPublished) async {
    await verifyAdministrator();
    await _database.setModulePublished(moduleId, isPublished);
  }

  @override
  Future<void> deleteAdminModule(int moduleId) async {
    await verifyAdministrator();
    await _database.deleteModule(moduleId);
  }

  @override
  Future<List<AdminDictionaryEntry>> fetchAdminDictionary({
    String query = '',
  }) async {
    await verifyAdministrator();
    return (await _database.adminVocabulary(query: query))
        .map(_adminDictionaryEntry)
        .toList();
  }

  @override
  Future<AdminDictionaryEntry> saveDictionaryEntry(
    Map<String, dynamic> entry, {
    int? entryId,
  }) async {
    await verifyAdministrator();
    if (entry['is_verified'] == true &&
        (entry['source'] as String? ?? '').trim().isEmpty) {
      throw const AuthFailure(
        'Provide a source before verifying a dictionary entry.',
      );
    }
    final id = await _database.saveVocabulary(entry, entryId: entryId);
    final row = (await _database.adminVocabulary()).firstWhere(
      (item) => item['id'] == id,
    );
    return _adminDictionaryEntry(row);
  }

  @override
  Future<void> deactivateDictionaryEntry(int entryId) async {
    await verifyAdministrator();
    await _database.deactivateVocabulary(entryId);
  }

  @override
  Future<AdminResource> uploadAdminResource({
    required String filename,
    required Uint8List bytes,
    int? moduleId,
    int? lessonIndex,
    int? vocabularyId,
  }) async {
    await verifyAdministrator();
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw const AuthFailure(
        'Choose a non-empty resource smaller than 25 MB.',
      );
    }
    final extension = filename.split('.').last.toLowerCase();
    const supported = {
      'pdf': 'application/pdf',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'webp': 'image/webp',
    };
    final mediaType = supported[extension];
    if (mediaType == null) {
      throw const AuthFailure(
        'Only PDF, image, and audio resources are supported.',
      );
    }
    final id = const Uuid().v4();
    await _database.saveResource(
      id: id,
      name: filename,
      mediaType: mediaType,
      bytes: bytes,
      moduleId: moduleId,
      lessonIndex: lessonIndex,
      vocabularyId: vocabularyId,
    );
    return AdminResource(
      id: id,
      name: filename,
      mediaType: mediaType,
      sizeBytes: bytes.length,
      url: 'local://resource/$id',
      createdAt: DateTime.now().toUtc(),
      moduleId: moduleId,
      lessonIndex: lessonIndex,
      vocabularyId: vocabularyId,
    );
  }

  @override
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String learningPreference,
  }) async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    if (!await isUsernameAvailable(username)) {
      throw const AuthFailure('That username is already used on this device.');
    }
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Firebase did not return the new account.');
      }
      await user.updateDisplayName(fullName.trim());
      await _database.createLearner(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        username: username.trim(),
        fullName: fullName.trim(),
        learningPreference: learningPreference,
      );
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (error) {
        try {
          await auth.signOut();
        } on FirebaseAuthException {
          throw AuthFailure(
            'Your account was created, but Firebase could not send the verification email. Your session is still active; request another email from the verification screen.',
            isOffline: error.code == 'network-request-failed',
          );
        }
        throw AuthFailure(
          'Your account was created, but the verification email could not be sent. ${_verificationErrorMessage(error.code)}',
          isOffline: error.code == 'network-request-failed',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _firebaseErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    } on DatabaseException {
      throw const AuthFailure(
        'Your Firebase account was created, but the local profile could not be saved. Sign in again to restore it.',
      );
    }
  }

  @override
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    final email = username.trim().toLowerCase();
    if (!email.contains('@')) {
      throw const AuthFailure(
        'Sign in with the email address on your account.',
      );
    }
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Firebase did not return your account.');
      }
      await user.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null) {
        throw const AuthFailure('Your session expired. Sign in again.');
      }
      await refreshedUser.getIdToken(true);
      await _database.ensureLearner(
        uid: refreshedUser.uid,
        email: refreshedUser.email ?? email,
        fullName: refreshedUser.displayName ?? '',
      );
      await _database.recordLearnerLogin(
        uid: refreshedUser.uid,
        email: refreshedUser.email ?? email,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _firebaseErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    } on DatabaseException {
      throw const AuthFailure(
        'You are signed in, but your local learning profile could not be initialized. Retry profile loading, or sign out and sign in again.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    try {
      await auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw AuthFailure(
        _firebaseErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    }
  }

  @override
  Future<void> resendVerificationEmail() async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    final user = _requireUser();
    try {
      await user.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null) {
        throw const AuthFailure('Your session expired. Sign in again.');
      }
      if (refreshedUser.emailVerified) {
        throw const AuthFailure(
          'This email is already verified. Try signing in again.',
        );
      }
      if (refreshedUser.email == null) {
        throw const AuthFailure('Your Firebase account has no email address.');
      }
      await refreshedUser.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _verificationErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    }
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    final user = _requireUser();
    try {
      await user.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null) {
        throw const AuthFailure('Your session expired. Sign in again.');
      }
      await refreshedUser.getIdToken(true);
      return auth.currentUser?.emailVerified ?? refreshedUser.emailVerified;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(
        _verificationErrorMessage(error.code),
        isOffline: error.code == 'network-request-failed',
      );
    }
  }

  @override
  Future<void> signOut() async {
    final auth = firebaseAuth;
    if (auth == null) throw AuthFailure(_configurationError);
    try {
      await auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseErrorMessage(error.code));
    }
  }

  User _requireUser() {
    final user = firebaseAuth?.currentUser;
    if (user == null) {
      throw const AuthFailure('Sign in to continue.');
    }
    return user;
  }

  Future<String> _ownerUid() async {
    final user = firebaseAuth?.currentUser;
    if (user != null) {
      await _database.ensureLearner(
        uid: user.uid,
        email: user.email ?? '',
        fullName: user.displayName ?? '',
      );
      return user.uid;
    }
    await _database.ensureLearner(
      uid: 'offline-guest',
      email: '',
      fullName: 'Offline learner',
    );
    return 'offline-guest';
  }

  Future<int> _currentStreak(String uid) async {
    final rows = await (await _database.database).query(
      'lesson_completions',
      columns: ['completed_at'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    final dates = rows
        .map((row) => DateTime.parse(row['completed_at']! as String))
        .map(localDateKey)
        .toSet();
    // Walk back one local calendar day at a time (date arithmetic, not
    // 24-hour durations).
    var current = localCalendarDate(_database.clock());
    DateTime previousDay(DateTime date) =>
        DateTime.utc(date.year, date.month, date.day - 1);
    if (!dates.contains(dateKeyOf(current))) current = previousDay(current);
    var streak = 0;
    while (dates.contains(dateKeyOf(current))) {
      streak++;
      current = previousDay(current);
    }
    return streak;
  }

  int _longestStreak(List<DateTime> activeDates) {
    final dates = activeDates.toSet().toList()..sort();
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final date in dates) {
      if (previous != null && date.difference(previous).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previous = date;
    }
    return longest;
  }

  Future<bool> _hasPerfectQuiz(String uid) async {
    final rows = await (await _database.database).query(
      'quiz_results',
      columns: ['id'],
      where: 'uid = ? AND score = 100',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _hasHistoryEvent(
    String uid,
    String eventType,
    String date,
  ) async {
    final rows = await (await _database.database).query(
      'learning_history',
      columns: ['id'],
      where: 'uid = ? AND event_type = ? AND entity_id = ?',
      whereArgs: [uid, eventType, date],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<LearnerCertificate>> _completedCertificates(String uid) async {
    final db = await _database.database;
    final modules = await _database.modules(uid: uid);
    final certificates = <LearnerCertificate>[];
    for (final module in modules) {
      final count = module['lesson_count']! as int;
      if (count == 0 || module['completed_lessons'] != count) continue;
      final completions = await db.query(
        'lesson_completions',
        columns: ['completed_at'],
        where: 'uid = ? AND module_id = ?',
        whereArgs: [uid, module['id']],
        orderBy: 'completed_at DESC',
        limit: 1,
      );
      if (completions.isEmpty) continue;
      final profile = await _database.learner(uid);
      certificates.add(
        LearnerCertificate(
          certificateId: '$uid-${module['id']}',
          moduleId: module['id']! as int,
          moduleTitle: module['title']! as String,
          learnerName:
              (profile?['nickname'] as String?)?.trim().isNotEmpty == true
              ? profile!['nickname']! as String
              : profile?['full_name'] as String? ?? 'LearnLite learner',
          issuedAt: DateTime.parse(
            completions.single['completed_at']! as String,
          ),
        ),
      );
    }
    return certificates;
  }

  RewardBadge _badge({
    required String id,
    required String title,
    required String description,
    required int progress,
    required int target,
  }) => RewardBadge(
    id: id,
    title: title,
    description: description,
    earned: progress >= target,
    progress: progress.clamp(0, target).toInt(),
    target: target,
  );

  AdminResource _resourceFromRow(Map<String, Object?> row) => AdminResource(
    id: row['id']! as String,
    name: row['name']! as String,
    mediaType: row['media_type']! as String,
    sizeBytes: row['size_bytes']! as int,
    url: 'local://resource/${row['id']}',
    createdAt: DateTime.tryParse(row['created_at']! as String),
    moduleId: row['module_id'] as int?,
    lessonIndex: row['lesson_index'] as int?,
    vocabularyId: row['vocabulary_id'] as int?,
  );

  AdminDictionaryEntry _adminDictionaryEntry(Map<String, Object?> row) =>
      AdminDictionaryEntry.fromJson({
        'id': row['id'],
        'subanen_word': row['subanen'],
        'english_translation': row['english'],
        'bisaya_translation': row['bisaya'],
        'pronunciation': row['pronunciation'],
        'module': row['module'],
        'topic': row['topic'],
        'source': row['source'],
        'audio_url': row['audio_url'],
        'review_status': row['review_status'],
        'is_verified': row['is_verified'] == 1,
        'is_active': row['is_active'] == 1,
      });

  Map<String, dynamic> _dictionaryJson(Map<String, Object?> row) => {
    'id': row['id'],
    'subanen_word': row['subanen'],
    'english_translation': row['english'],
    'bisaya_translation': row['bisaya'],
    'pronunciation': row['pronunciation'],
    'module': row['module'],
    'topic': row['topic'],
    'source': row['source'],
    'audio_url': row['audio_url'],
    'review_status': row['review_status'],
  };

  String _languageColumn(String language) => switch (language.toLowerCase()) {
    'subanen' => 'subanen',
    'english' => 'english',
    'cebuano' || 'bisaya' => 'bisaya',
    _ => throw const AuthFailure('This language pair is not supported.'),
  };

  String _weekday(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  String get _configurationError =>
      initializationError ??
      'Firebase is not configured. Register Android package com.example.learnlite and supply the LearnLite Firebase app options.';

  String _firebaseErrorMessage(String code) => switch (code) {
    'network-request-failed' => 'Could not reach Firebase. Check your Internet connection. Previously signed-in learners can continue with saved offline content.',
    'email-already-in-use' =>
      'An account already uses this email address. Try signing in instead.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' =>
      'Use a stronger password that meets Firebase password policy.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-login-credentials' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'user-disabled' => 'This account is disabled. Contact LearnLite support.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled for this Firebase project.',
    'requires-recent-login' =>
      'Sign in again before changing your account details.',
    'too-many-requests' => 'Too many attempts. Wait a little and try again.',
    _ => 'Firebase sign-in could not be completed. Please try again.',
  };

  String _verificationErrorMessage(String code) => switch (code) {
    'network-request-failed' =>
      'Could not reach Firebase. Check your Internet connection and try again.',
    'expired-action-code' =>
      'This verification link has expired. Request a new verification email.',
    'invalid-action-code' => 'This verification link is invalid or was already used. Request a new verification email.',
    'email-already-verified' =>
      'This email is already verified. Try signing in again.',
    'too-many-requests' =>
      'Too many verification attempts. Wait a little before trying again.',
    'operation-not-allowed' => 'Email verification is not available for this Firebase project. Contact LearnLite support.',
    _ => 'Firebase could not send or check your verification email. Please try again.',
  };
}

/// Records how long each startup step takes and prints one summary line in
/// debug and profile builds (never in release builds).
class _StartupTimer {
  final _stopwatch = Stopwatch()..start();
  final _laps = <String>[];
  Duration _last = Duration.zero;

  void lap(String step) {
    final now = _stopwatch.elapsed;
    _laps.add('$step ${(now - _last).inMilliseconds}ms');
    _last = now;
  }

  void report() {
    if (kReleaseMode) return;
    debugPrint(
      'LearnLite startup: ${_laps.join(' · ')} · '
      'total ${_stopwatch.elapsedMilliseconds}ms',
    );
  }
}

class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  AuthFailure get _failure =>
      const AuthFailure('Firebase Authentication is not configured.');

  @override
  Stream<AuthSession?> get authStateChanges => Stream<AuthSession?>.value(null);

  @override
  bool get isConfigured => false;

  @override
  String? get initializationError => null;

  @override
  Future<bool> isUsernameAvailable(String username) => Future.value(true);

  @override
  Future<LearnerProfile> fetchProfile() => Future.error(_failure);

  @override
  Future<LearnerProfile> updateAvatarProfile(LearnerProfile profile) =>
      Future.error(_failure);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => Future.error(_failure);

  @override
  Future<List<LearningModule>> fetchModules({String search = ''}) =>
      Future.error(_failure);

  @override
  Future<LearningModule> fetchModule(int moduleId) => Future.error(_failure);

  @override
  Future<LearningModule> startModuleLesson(int moduleId, int lessonIndex) =>
      Future.error(_failure);

  @override
  Future<LearningModule> completeModuleLesson(int moduleId, int lessonIndex) =>
      Future.error(_failure);

  @override
  Future<QuizResult> submitLessonQuiz(
    int moduleId,
    int lessonIndex,
    List<int> answers,
  ) => Future.error(_failure);

  @override
  Future<List<QuizResult>> fetchLessonQuizAttempts(
    int moduleId,
    int lessonIndex,
  ) => Future.error(_failure);

  @override
  Future<RewardsOverview> fetchRewards() => Future.error(_failure);

  @override
  Future<Uint8List> fetchCertificatePdf(String certificateId) =>
      Future.error(_failure);

  @override
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String learningPreference,
  }) => Future.error(_failure);

  @override
  Future<void> signIn({required String username, required String password}) =>
      Future.error(_failure);

  @override
  Future<void> sendPasswordResetEmail(String email) => Future.error(_failure);

  @override
  Future<void> resendVerificationEmail() => Future.error(_failure);

  @override
  Future<bool> refreshEmailVerification() => Future.error(_failure);

  @override
  Future<void> signOut() => Future.error(_failure);
}
