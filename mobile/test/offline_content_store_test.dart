import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/core/offline_content_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'stores only packs explicitly downloaded and removes them cleanly',
    () async {
      final store = OfflineContentStore();
      expect(await store.listPacks(), isEmpty);

      await store.savePack({
        'id': 'module:7',
        'type': 'module',
        'title': 'Content supplied by an administrator',
        'size_bytes': 3,
        'data': {
          'id': 7,
          'title': 'Content supplied by an administrator',
          'lessons': [],
        },
        'media': {'/resources/example': 'AQID'},
      });

      final packs = await store.listPacks();
      expect(packs, hasLength(1));
      expect(packs.single['id'], 'module:7');
      expect(packs.single['title'], 'Content supplied by an administrator');
      expect(await store.storageBytes(), greaterThan(0));

      await store.removePack('module:7');
      expect(await store.listPacks(), isEmpty);
      expect(await store.storageBytes(), 0);
    },
  );

  test('persists recent searches and queues idempotent completions', () async {
    final store = OfflineContentStore();
    await store.addRecentSearch(' verified entry ');
    await store.addRecentSearch('Verified Entry');
    expect(await store.recentSearches(), ['Verified Entry']);

    await store.queueCompletion(
      eventId: 'offline-event-1',
      moduleId: 7,
      lessonIndex: 2,
      completedAt: DateTime.utc(2025, 1, 2),
    );
    await store.queueCompletion(
      eventId: 'offline-event-2',
      moduleId: 7,
      lessonIndex: 2,
      completedAt: DateTime.utc(2025, 1, 3),
    );
    expect(await store.pendingCompletions(), [
      {
        'event_id': 'offline-event-1',
        'user_id': 'legacy',
        'module_id': 7,
        'lesson_index': 2,
        'completed_at': '2025-01-02T00:00:00.000Z',
      },
    ]);

    await store.acknowledgeCompletions({'offline-event-1'});
    expect(await store.pendingCompletions(), isEmpty);
  });

  test('isolates queued progress and acknowledgements by learner', () async {
    final store = OfflineContentStore();
    await store.queueCompletion(
      userId: 'learner-a',
      eventId: 'event-a',
      moduleId: 7,
      lessonIndex: 2,
      completedAt: DateTime.utc(2025, 1, 2),
    );
    await store.queueCompletion(
      userId: 'learner-b',
      eventId: 'event-b',
      moduleId: 7,
      lessonIndex: 2,
      completedAt: DateTime.utc(2025, 1, 3),
    );

    expect(
      (await store.pendingCompletions(userId: 'learner-a'))
          .map((event) => event['event_id']),
      ['event-a'],
    );
    expect(
      (await store.pendingCompletions(userId: 'learner-b'))
          .map((event) => event['event_id']),
      ['event-b'],
    );

    await store.acknowledgeCompletions({'event-a'}, userId: 'learner-a');

    expect(await store.pendingCompletions(userId: 'learner-a'), isEmpty);
    expect(
      (await store.pendingCompletions(userId: 'learner-b'))
          .map((event) => event['event_id']),
      ['event-b'],
    );
  });

  test('persists cached lesson progress separately for each learner', () async {
    final store = OfflineContentStore();
    await store.saveModuleProgress(
      userId: 'learner-a',
      moduleId: 7,
      completedLessonIndices: [2, 0, 2],
      lastLessonIndex: 2,
    );
    await store.saveModuleProgress(
      userId: 'learner-b',
      moduleId: 7,
      completedLessonIndices: [1],
      lastLessonIndex: 1,
    );

    expect(await store.readModuleProgress(userId: 'learner-a', moduleId: 7), {
      'completed_lesson_indices': [0, 2],
      'last_lesson_index': 2,
    });
    expect(await store.readModuleProgress(userId: 'learner-b', moduleId: 7), {
      'completed_lesson_indices': [1],
      'last_lesson_index': 1,
    });
  });
}
