import 'dart:typed_data';

import 'local_vocabulary.dart';

class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.subanenWord,
    required this.englishTranslation,
    this.bisayaTranslation,
    this.definition,
    this.exampleSentence,
    this.pronunciation,
    this.module,
    this.topic,
    this.audioUrl,
    this.source,
    this.reviewStatus,
  });

  final int id;
  final String subanenWord;
  final String englishTranslation;
  final String? bisayaTranslation;
  final String? definition;
  final String? exampleSentence;
  final String? pronunciation;
  final String? module;
  final String? topic;
  final String? audioUrl;
  final String? source;
  final String? reviewStatus;

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final word = json['subanen_word'];
    final translation = json['english_translation'];
    if (id is! int || word is! String || translation is! String) {
      throw const FormatException('Dictionary entry fields are missing.');
    }
    return DictionaryEntry(
      id: id,
      subanenWord: word,
      englishTranslation: translation,
      bisayaTranslation: json['bisaya_translation'] as String?,
      definition: json['definition'] as String?,
      exampleSentence: json['example_sentence'] as String?,
      pronunciation: json['pronunciation'] as String?,
      module: json['module'] as String?,
      topic: json['topic'] as String?,
      audioUrl: json['audio_url'] as String?,
      source: json['source'] as String?,
      reviewStatus: json['review_status'] as String?,
    );
  }
}

class DictionaryTranslation {
  const DictionaryTranslation({
    required this.entry,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translation,
  });

  final DictionaryEntry entry;
  final String sourceLanguage;
  final String targetLanguage;
  final String translation;

  factory DictionaryTranslation.fromJson(Map<String, dynamic> json) =>
      DictionaryTranslation(
        entry: DictionaryEntry.fromJson(json['entry'] as Map<String, dynamic>),
        sourceLanguage: json['source_language'] as String,
        targetLanguage: json['target_language'] as String,
        translation: json['translation'] as String,
      );
}

class ContentPackDescriptor {
  const ContentPackDescriptor({
    required this.id,
    required this.type,
    required this.title,
    required this.sizeBytes,
    this.downloaded = false,
  });

  final String id;
  final String type;
  final String title;
  final int sizeBytes;
  final bool downloaded;

  factory ContentPackDescriptor.fromJson(
    Map<String, dynamic> json, {
    bool downloaded = false,
  }) {
    final id = json['id'];
    final type = json['type'];
    final title = json['title'];
    if (id is! String || type is! String || title is! String) {
      throw const FormatException('Content pack fields are missing.');
    }
    return ContentPackDescriptor(
      id: id,
      type: type,
      title: title,
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : 0,
      downloaded: downloaded,
    );
  }
}

abstract interface class DictionaryGateway {
  Future<LocalVocabularyCatalog> localVocabulary();
  Future<void> setVocabularyLearningStatus({
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  });
  Future<List<DictionaryTranslation>> searchDictionary(
    String query, {
    String sourceLanguage = 'Subanen',
    String targetLanguage = 'English',
  });
  Future<List<String>> recentDictionarySearches();
  Future<void> recordDictionarySearch(String query);
  Future<List<ContentPackDescriptor>> availableContentPacks();
  Future<void> downloadContentPack(String id);
  Future<void> removeContentPack(String id);
  Future<List<ContentPackDescriptor>> downloadedContentPacks();
  Future<int> offlineStorageBytes();
  Future<Uint8List?> cachedResource(String path);
  Future<Uint8List> fetchResourceBytes(String path);
}

abstract interface class OfflineSyncStatusGateway {
  Future<String?> offlineSyncNotice();
}

class AdminResource {
  const AdminResource({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.sizeBytes,
    required this.url,
    this.createdAt,
    this.moduleId,
    this.lessonIndex,
    this.vocabularyId,
  });

  final String id;
  final String name;
  final String mediaType;
  final int sizeBytes;
  final String url;
  final DateTime? createdAt;
  final int? moduleId;
  final int? lessonIndex;
  final int? vocabularyId;

  factory AdminResource.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final mediaType = json['media_type'];
    final url = json['url'];
    if (id is! String ||
        name is! String ||
        mediaType is! String ||
        url is! String) {
      throw const FormatException('Resource fields are missing.');
    }
    return AdminResource(
      id: id,
      name: name,
      mediaType: mediaType,
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : 0,
      url: url,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      moduleId: json['module_id'] as int?,
      lessonIndex: json['lesson_index'] as int?,
      vocabularyId: json['vocabulary_id'] as int?,
    );
  }
}

class AdminModule {
  const AdminModule({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
    required this.isPublished,
  });

  final int id;
  final String title;
  final String description;
  final List<Map<String, dynamic>> lessons;
  final bool isPublished;

  factory AdminModule.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final lessons = json['lessons'];
    if (id is! int ||
        title is! String ||
        description is! String ||
        lessons is! List) {
      throw const FormatException('Administrator module fields are missing.');
    }
    return AdminModule(
      id: id,
      title: title,
      description: description,
      lessons: lessons
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      isPublished: json['is_published'] == true,
    );
  }
}

class AdminDictionaryEntry {
  const AdminDictionaryEntry({
    required this.id,
    required this.subanenWord,
    required this.englishTranslation,
    required this.isVerified,
    required this.isActive,
    this.bisayaTranslation,
    this.pronunciation,
    this.module,
    this.topic,
    this.source,
    this.audioUrl,
    this.reviewStatus,
  });

  final int id;
  final String subanenWord;
  final String englishTranslation;
  final bool isVerified;
  final bool isActive;
  final String? bisayaTranslation;
  final String? pronunciation;
  final String? module;
  final String? topic;
  final String? source;
  final String? audioUrl;
  final String? reviewStatus;

  factory AdminDictionaryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final word = json['subanen_word'];
    final translation = json['english_translation'];
    if (id is! int || word is! String || translation is! String) {
      throw const FormatException(
        'Administrator dictionary fields are missing.',
      );
    }
    return AdminDictionaryEntry(
      id: id,
      subanenWord: word,
      englishTranslation: translation,
      isVerified: json['is_verified'] == true,
      isActive: json['is_active'] == true,
      bisayaTranslation: json['bisaya_translation'] as String?,
      pronunciation: json['pronunciation'] as String?,
      module: json['module'] as String?,
      topic: json['topic'] as String?,
      source: json['source'] as String?,
      audioUrl: json['audio_url'] as String?,
      reviewStatus: json['review_status'] as String?,
    );
  }
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.totalModules,
    required this.publishedModules,
    required this.totalLessons,
    required this.verifiedDictionaryEntries,
    required this.uploadedResources,
    required this.quizAttempts,
    required this.recentUploads,
    required this.activity,
  });

  final int totalModules;
  final int publishedModules;
  final int totalLessons;
  final int verifiedDictionaryEntries;
  final int uploadedResources;
  final int quizAttempts;
  final List<AdminResource> recentUploads;
  final List<Map<String, dynamic>> activity;

  factory AdminDashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => AdminDashboardSummary(
    totalModules: _integer(json['total_modules']),
    publishedModules: _integer(json['published_modules']),
    totalLessons: _integer(json['total_lessons']),
    verifiedDictionaryEntries: _integer(json['verified_dictionary_entries']),
    uploadedResources: _integer(json['uploaded_resources']),
    quizAttempts: _integer(json['quiz_attempts']),
    recentUploads: (json['recent_uploads'] as List? ?? const [])
        .map(
          (item) =>
              AdminResource.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    activity: (json['activity'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
  );
}

int _integer(dynamic value) => value is int ? value : 0;

abstract interface class AdminGateway {
  Future<void> verifyAdministrator();
  Future<AdminDashboardSummary> fetchAdminSummary();
  Future<List<AdminModule>> fetchAdminModules();
  Future<AdminModule> createAdminModule(Map<String, dynamic> module);
  Future<AdminModule> updateAdminModule(
    int moduleId,
    Map<String, dynamic> module,
  );
  Future<void> setModulePublished(int moduleId, bool isPublished);
  Future<void> deleteAdminModule(int moduleId);
  Future<List<AdminDictionaryEntry>> fetchAdminDictionary({String query = ''});
  Future<AdminDictionaryEntry> saveDictionaryEntry(
    Map<String, dynamic> entry, {
    int? entryId,
  });
  Future<void> deactivateDictionaryEntry(int entryId);
  Future<AdminResource> uploadAdminResource({
    required String filename,
    required Uint8List bytes,
    int? moduleId,
    int? lessonIndex,
    int? vocabularyId,
  });
}
