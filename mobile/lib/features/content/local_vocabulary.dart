import 'dart:convert';

import 'package:flutter/services.dart';

class LocalVocabularyEntry {
  const LocalVocabularyEntry({
    this.id,
    required this.english,
    required this.bisaya,
    required this.subanen,
    required this.module,
    required this.topic,
    required this.variety,
    required this.alternateForms,
    required this.source,
    required this.reviewStatus,
    required this.notes,
    required this.sourceFile,
    required this.sourceRow,
    this.isLearned = false,
    this.isBookmarked = false,
  });

  final int? id;
  final String english;
  final String bisaya;
  final String subanen;
  final String module;
  final String topic;
  final String variety;
  final String alternateForms;
  final String source;
  final String reviewStatus;
  final String notes;
  final String sourceFile;
  final int sourceRow;
  final bool isLearned;
  final bool isBookmarked;

  bool get needsSubanenForm => subanen.trim().isEmpty;

  // Entries are immutable, so the lowercase search text is computed once per
  // entry instead of on every keystroke.
  static final _searchableTextCache = Expando<String>('searchableText');

  String get searchableText => _searchableTextCache[this] ??= [
    english,
    bisaya,
    subanen,
    module,
    topic,
    variety,
    alternateForms,
    source,
    notes,
  ].join(' ').toLowerCase();

  String get category => topic.trim().isNotEmpty ? topic.trim() : module.trim();
}

class LocalVocabularyCatalog {
  const LocalVocabularyCatalog({
    required this.vocabulary,
    required this.starterList,
    required this.stillNeeded,
    required this.sourceRowCounts,
  });

  final List<LocalVocabularyEntry> vocabulary;
  final List<LocalVocabularyEntry> starterList;
  final List<LocalVocabularyEntry> stillNeeded;
  final Map<String, int> sourceRowCounts;

  List<LocalVocabularyEntry> search(
    String query, {
    String source = 'All',
    String category = 'All categories',
  }) {
    final normalized = query.trim().toLowerCase();
    final entries = switch (source) {
      'LearnLite vocabulary' => vocabulary,
      'Starter list' => starterList,
      'Still needed' => stillNeeded,
      _ => [...vocabulary, ...starterList, ...stillNeeded],
    };
    return entries.where((entry) {
      final matchesQuery =
          normalized.isEmpty || entry.searchableText.contains(normalized);
      final matchesCategory =
          category == 'All categories' || entry.category == category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<String> get categories => {
    for (final entry in [...vocabulary, ...starterList, ...stillNeeded])
      if (entry.category.isNotEmpty) entry.category,
  }.toList()..sort();
}

class LocalVocabularyRepository {
  LocalVocabularyRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Bump when the way workbook columns map to vocabulary fields changes, so
  /// devices re-import even if the JSON files are unchanged.
  static const importerVersion = 1;

  static const assetPaths = [
    'assets/vocabulary/learnlite_subanen_vocabulary.json',
    'assets/vocabulary/learnlite_still_needed.json',
    'assets/vocabulary/subanen_vocabulary_starter_list.json',
  ];

  /// A cheap fingerprint (64-bit FNV-1a) of the bundled vocabulary files and
  /// the importer version. Startup compares it with the stored value and
  /// skips the import when nothing changed.
  Future<String> fingerprint() async {
    var hash = 0xcbf29ce484222325;
    void mix(int value) {
      hash ^= value & 0xff;
      hash *= 0x100000001b3;
      hash ^= (value >> 8) & 0xff;
      hash *= 0x100000001b3;
    }

    mix(importerVersion);
    for (final path in assetPaths) {
      for (final unit in (await _bundle.loadString(path)).codeUnits) {
        mix(unit);
      }
      mix(0x1f);
    }
    return 'v$importerVersion:${hash.toUnsigned(64).toRadixString(16)}';
  }

  Future<LocalVocabularyCatalog> load() async {
    final vocabularyData = await _readAsset(assetPaths[0]);
    final neededData = await _readAsset(assetPaths[1]);
    final starterData = await _readAsset(assetPaths[2]);

    final vocabulary = _entries(
      vocabularyData,
      sourceFile: 'LearnLite-Subanen-Vocabulary.xlsx',
      fields: const _Fields(
        english: 'D',
        bisaya: 'E',
        subanen: 'F',
        module: 'B',
        topic: 'C',
        variety: 'G',
        alternateForms: 'H',
        source: 'I',
        reviewStatus: 'K',
        notes: 'L',
      ),
    );
    final needed =
        _entries(
              neededData,
              sourceFile: 'LearnLite-Subanen-Vocabulary.xlsx',
              fields: const _Fields(
                english: 'C',
                bisaya: 'D',
                subanen: 'E',
                module: 'B',
                variety: 'F',
                notes: 'J',
              ),
              reviewStatus: 'Needs Subanen form',
            )
            .where(
              (entry) =>
                  entry.english.isNotEmpty &&
                  !entry.notes.toLowerCase().startsWith('example:'),
            )
            .toList();
    final starter = _entries(
      starterData,
      sourceFile: 'Subanen_Vocabulary_Starter_List.xlsx',
      fields: const _Fields(
        english: 'E',
        bisaya: 'D',
        subanen: 'C',
        module: 'B',
        notes: 'F',
      ),
      reviewStatus: 'Starter list · verify with a fluent speaker',
    );

    return LocalVocabularyCatalog(
      vocabulary: vocabulary,
      starterList: starter,
      stillNeeded: needed,
      sourceRowCounts: {
        'vocabulary': _rowCount(vocabularyData),
        'still_needed': _rowCount(neededData),
        'starter_list': _rowCount(starterData),
      },
    );
  }

  Future<Map<String, dynamic>> _readAsset(String path) async {
    final decoded = jsonDecode(await _bundle.loadString(path));
    if (decoded is! Map<String, dynamic> ||
        decoded['headers'] is! Map ||
        decoded['rows'] is! List) {
      throw FormatException('Vocabulary asset has an invalid structure: $path');
    }
    return decoded;
  }

  int _rowCount(Map<String, dynamic> data) => (data['rows'] as List).length;

  List<LocalVocabularyEntry> _entries(
    Map<String, dynamic> data, {
    required String sourceFile,
    required _Fields fields,
    String? reviewStatus,
  }) {
    final rows = data['rows'] as List;
    final entries = <LocalVocabularyEntry>[];
    for (final item in rows) {
      if (item is! Map<String, dynamic> ||
          item['cells'] is! Map ||
          item['row'] is! int) {
        throw const FormatException(
          'Vocabulary asset contains an invalid row.',
        );
      }
      final cells = Map<String, dynamic>.from(item['cells'] as Map);
      String value(String column) {
        final cell = cells[column];
        return cell is String ? cell.trim() : '';
      }

      final english = value(fields.english);
      final bisaya = value(fields.bisaya);
      final subanen = value(fields.subanen);
      if (english.isEmpty && bisaya.isEmpty && subanen.isEmpty) continue;

      entries.add(
        LocalVocabularyEntry(
          english: english,
          bisaya: bisaya,
          subanen: subanen,
          module: value(fields.module),
          topic: value(fields.topic),
          variety: value(fields.variety),
          alternateForms: value(fields.alternateForms),
          source: value(fields.source),
          reviewStatus: reviewStatus ?? value(fields.reviewStatus),
          notes: value(fields.notes),
          sourceFile: sourceFile,
          sourceRow: item['row'] as int,
        ),
      );
    }
    return entries;
  }
}

class _Fields {
  const _Fields({
    required this.english,
    required this.bisaya,
    required this.subanen,
    this.module = '',
    this.topic = '',
    this.variety = '',
    this.alternateForms = '',
    this.source = '',
    this.reviewStatus = '',
    this.notes = '',
  });

  final String english;
  final String bisaya;
  final String subanen;
  final String module;
  final String topic;
  final String variety;
  final String alternateForms;
  final String source;
  final String reviewStatus;
  final String notes;
}
