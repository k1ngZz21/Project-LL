import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStorageFailure implements Exception {
  const OfflineStorageFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineContentStore {
  static const _packIndexKey = 'learnlite.offline.packs.v1';
  static const _recentSearchesKey = 'learnlite.dictionary.recent.v1';
  static const _pendingCompletionsKey = 'learnlite.progress.pending.v1';
  static const _syncNoticeKey = 'learnlite.progress.sync_notice.v1';
  static const _profileKey = 'learnlite.profile.cached.v1';
  static const _moduleProgressKey = 'learnlite.offline.progress.v1';

  Future<List<Map<String, dynamic>>> listPacks() async {
    final preferences = await SharedPreferences.getInstance();
    final index = _decodeList(preferences.getString(_packIndexKey));
    final packs = <Map<String, dynamic>>[];
    for (final item in index) {
      if (item case {'id': final String id}) {
        final encoded = preferences.getString(_packKey(id));
        if (encoded == null) continue;
        final decoded = _decodeObject(encoded);
        packs.add({
          ...item,
          'data': decoded['data'],
          'media': decoded['media'] ?? <String, String>{},
        });
      }
    }
    return packs;
  }

  Future<Map<String, dynamic>?> readPack(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_packKey(id));
    return encoded == null ? null : _decodeObject(encoded);
  }

  Future<void> savePack(Map<String, dynamic> pack) async {
    final id = pack['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Offline content pack has no identifier.');
    }
    final preferences = await SharedPreferences.getInstance();
    final media = pack['media'];
    final data = pack['data'];
    if (media is! Map || data == null) {
      throw const FormatException('Offline content pack is incomplete.');
    }
    final normalizedMedia = <String, String>{};
    for (final entry in media.entries) {
      if (entry.key is String && entry.value is String) {
        normalizedMedia[entry.key as String] = entry.value as String;
      }
    }
    final encodedPack = jsonEncode({'data': data, 'media': normalizedMedia});
    final previousPack = preferences.getString(_packKey(id));
    final oldIndex = _decodeList(preferences.getString(_packIndexKey));
    Map<String, dynamic>? oldMetadata;
    for (final item in oldIndex) {
      if (item['id'] == id) {
        oldMetadata = item;
        break;
      }
    }
    final index = oldIndex.where((item) => item['id'] != id).toList();
    index.add({
      'id': id,
      'type': pack['type'] ?? oldMetadata?['type'],
      'title': pack['title'] ?? oldMetadata?['title'],
      'size_bytes': utf8.encode(encodedPack).length,
      'downloaded_at': DateTime.now().toUtc().toIso8601String(),
    });
    try {
      await _saveString(preferences, _packKey(id), encodedPack);
      await _saveString(preferences, _packIndexKey, jsonEncode(index));
    } on OfflineStorageFailure {
      if (previousPack == null) {
        await preferences.remove(_packKey(id));
      } else {
        await _saveString(preferences, _packKey(id), previousPack);
      }
      rethrow;
    }
  }

  Future<void> removePack(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_packKey(id));
    final index = _decodeList(preferences.getString(_packIndexKey))
        .where((item) => item['id'] != id)
        .toList();
    await preferences.setString(_packIndexKey, jsonEncode(index));
  }

  Future<List<String>> recentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    final decoded = _decodeList(preferences.getString(_recentSearchesKey));
    return decoded.map((item) => item['query']).whereType<String>().toList();
  }

  Future<void> addRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final current = await recentSearches();
    final next = [
      normalized,
      ...current.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(10);
    await preferences.setString(
      _recentSearchesKey,
      jsonEncode(next.map((query) => {'query': query}).toList()),
    );
  }

  Future<int> storageBytes() async {
    final packs = await listPacks();
    return packs.fold<int>(
      0,
      (total, pack) => total + (pack['size_bytes'] as int? ?? 0),
    );
  }

  Future<void> saveProfile(
    Map<String, dynamic> profile, {
    required String userId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKeyFor(userId), jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> readProfile({required String userId}) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_profileKeyFor(userId));
    return encoded == null ? null : _decodeObject(encoded);
  }

  Future<Map<String, dynamic>?> readModuleProgress({
    required String userId,
    required int moduleId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(
      _moduleProgressKeyFor(userId, moduleId),
    );
    return encoded == null ? null : _decodeObject(encoded);
  }

  Future<void> saveModuleProgress({
    required String userId,
    required int moduleId,
    required List<int> completedLessonIndices,
    int? lastLessonIndex,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final completed = completedLessonIndices.toSet().toList()..sort();
    final saved = await preferences.setString(
      _moduleProgressKeyFor(userId, moduleId),
      jsonEncode({
        'completed_lesson_indices': completed,
        'last_lesson_index': lastLessonIndex,
      }),
    );
    if (!saved) {
      throw const OfflineStorageFailure(
        'Could not save your learning progress on this device.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> pendingCompletions({
    String? userId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeList(preferences.getString(_pendingCompletionsKey))
        .where((event) => event['user_id'] == (userId ?? 'legacy'))
        .toList();
  }

  Future<void> queueCompletion({
    String? userId,
    required String eventId,
    required int moduleId,
    required int lessonIndex,
    required DateTime completedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final pending = _decodeList(preferences.getString(_pendingCompletionsKey));
    final ownerId = userId ?? 'legacy';
    if (pending.any(
      (event) =>
          event['user_id'] == ownerId &&
          event['module_id'] == moduleId &&
          event['lesson_index'] == lessonIndex,
    )) {
      return;
    }
    pending.add({
      'event_id': eventId,
      'user_id': ownerId,
      'module_id': moduleId,
      'lesson_index': lessonIndex,
      'completed_at': completedAt.toUtc().toIso8601String(),
    });
    await preferences.setString(_pendingCompletionsKey, jsonEncode(pending));
  }

  Future<void> acknowledgeCompletions(
    Set<String> eventIds, {
    String? userId,
  }) async {
    if (eventIds.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final allPending = _decodeList(
      preferences.getString(_pendingCompletionsKey),
    );
    allPending.removeWhere(
      (event) =>
          event['user_id'] == (userId ?? 'legacy') &&
          eventIds.contains(event['event_id']),
    );
    await preferences.setString(_pendingCompletionsKey, jsonEncode(allPending));
  }

  Future<String?> syncNotice() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_syncNoticeKey);
  }

  Future<void> setSyncNotice(String? notice) async {
    final preferences = await SharedPreferences.getInstance();
    if (notice == null) {
      await preferences.remove(_syncNoticeKey);
    } else {
      await preferences.setString(_syncNoticeKey, notice);
    }
  }

  Future<void> updateDownloadedModule(
    int moduleId,
    Map<String, dynamic> data,
  ) async {
    final id = 'module:$moduleId';
    final pack = await readPack(id);
    if (pack == null) return;
    await savePack({...pack, 'data': data});
  }

  Future<Map<String, dynamic>> exportLegacyData() async {
    final preferences = await SharedPreferences.getInstance();
    final profiles = <String, Map<String, dynamic>>{};
    final progress = <Map<String, dynamic>>[];
    for (final key in preferences.getKeys()) {
      if (key.startsWith('$_profileKey.')) {
        final uid = key.substring(_profileKey.length + 1);
        final encoded = preferences.getString(key);
        if (encoded != null) profiles[uid] = _decodeObject(encoded);
      } else if (key.startsWith('$_moduleProgressKey.')) {
        final suffix = key.substring(_moduleProgressKey.length + 1);
        final separator = suffix.lastIndexOf('.');
        if (separator <= 0) continue;
        final moduleId = int.tryParse(suffix.substring(separator + 1));
        final encoded = preferences.getString(key);
        if (moduleId == null || encoded == null) continue;
        progress.add({
          'uid': suffix.substring(0, separator),
          'module_id': moduleId,
          ..._decodeObject(encoded),
        });
      }
    }

    return {
      'profiles': profiles,
      'progress': progress,
      'completions': _decodeList(preferences.getString(_pendingCompletionsKey)),
      'recent_searches': _decodeList(preferences.getString(_recentSearchesKey)),
      'packs': await listPacks(),
    };
  }

  String _packKey(String id) => 'learnlite.offline.pack.$id';

  String _profileKeyFor(String userId) => '$_profileKey.$userId';

  String _moduleProgressKeyFor(String userId, int moduleId) =>
      '$_moduleProgressKey.$userId.$moduleId';

  Future<void> _saveString(
    SharedPreferences preferences,
    String key,
    String value,
  ) async {
    try {
      if (!await preferences.setString(key, value)) {
        throw const OfflineStorageFailure(
          'This device could not save the content pack. Free storage space and try again.',
        );
      }
    } on PlatformException {
      throw const OfflineStorageFailure(
        'This device could not save the content pack. Free storage space and try again.',
      );
    } on MissingPluginException {
      throw const OfflineStorageFailure(
        'Local storage is unavailable on this device.',
      );
    }
  }

  List<Map<String, dynamic>> _decodeList(String? encoded) {
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('Saved LearnLite data is invalid.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _decodeObject(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved LearnLite data is invalid.');
    }
    return decoded;
  }
}
