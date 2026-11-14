import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import 'content_gateway.dart';
import 'local_vocabulary.dart';
import 'vocabulary_practice_screen.dart';

class LocalVocabularyScreen extends StatefulWidget {
  const LocalVocabularyScreen({required this.gateway, super.key});

  final DictionaryGateway gateway;

  @override
  State<LocalVocabularyScreen> createState() => _LocalVocabularyScreenState();
}

class _LocalVocabularyScreenState extends State<LocalVocabularyScreen> {
  final _queryController = TextEditingController();
  late Future<LocalVocabularyCatalog> _catalogFuture;
  Timer? _searchDebounce;
  String _searchQuery = '';
  int? _savingVocabularyId;
  String _source = 'All';

  static const _sources = [
    'All',
    'LearnLite vocabulary',
    'Starter list',
    'Still needed',
  ];

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.gateway.localVocabulary();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  Future<void> _setVocabularyStatus(
    LocalVocabularyEntry entry, {
    bool? learned,
    bool? bookmarked,
  }) async {
    final id = entry.id;
    if (id == null) return;
    setState(() => _savingVocabularyId = id);
    try {
      await widget.gateway.setVocabularyLearningStatus(
        vocabularyId: id,
        learned: learned ?? entry.isLearned,
        bookmarked: bookmarked ?? entry.isBookmarked,
      );
      if (mounted) {
        setState(() => _catalogFuture = widget.gateway.localVocabulary());
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on DatabaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save vocabulary progress.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingVocabularyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Offline Vocabulary Reference'),
              const SizedBox(height: 8),
              Text(
                'Bundled from the original workbooks. Entries retain their review status and are not presented as verified translations.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('open-vocabulary-practice'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => VocabularyPracticeScreen(
                        gateway: widget.gateway,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.style_outlined),
                  label: const Text('Practice vocabulary'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                onChanged: _handleSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search words and meanings',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final source in _sources)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(source),
                          selected: _source == source,
                          onSelected: (_) => setState(() => _source = source),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<LocalVocabularyCatalog>(
                future: _catalogFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'Vocabulary could not be loaded',
                      message:
                          'The bundled vocabulary data is unavailable. ${snapshot.error}',
                    );
                  }
                  final catalog = snapshot.data!;
                  final entries = catalog.search(_searchQuery, source: _source);
                  if (entries.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off,
                      title: 'No matching workbook entries',
                      message: 'Try another word or choose a different source.',
                    );
                  }
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${entries.length} workbook ${entries.length == 1 ? 'entry' : 'entries'}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final entry in entries) ...[
                        _VocabularyCard(
                          entry: entry,
                          isSaving: _savingVocabularyId == entry.id,
                          onLearnedChanged: (learned) =>
                              _setVocabularyStatus(entry, learned: learned),
                          onBookmarkedChanged: (bookmarked) =>
                              _setVocabularyStatus(
                                entry,
                                bookmarked: bookmarked,
                              ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _VocabularyCard extends StatelessWidget {
  const _VocabularyCard({
    required this.entry,
    required this.isSaving,
    required this.onLearnedChanged,
    required this.onBookmarkedChanged,
  });

  final LocalVocabularyEntry entry;
  final bool isSaving;
  final ValueChanged<bool> onLearnedChanged;
  final ValueChanged<bool> onBookmarkedChanged;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: entry.isLearned
                    ? 'Mark as not learned'
                    : 'Mark as learned',
                onPressed: isSaving
                    ? null
                    : () => onLearnedChanged(!entry.isLearned),
                icon: Icon(
                  entry.isLearned
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                ),
              ),
              IconButton(
                tooltip: entry.isBookmarked ? 'Remove saved word' : 'Save word',
                onPressed: isSaving
                    ? null
                    : () => onBookmarkedChanged(!entry.isBookmarked),
                icon: Icon(
                  entry.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
              ),
            ],
          ),
        ),
        Text(
          entry.subanen.isEmpty
              ? 'Subanen form not yet entered'
              : entry.subanen,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
        if (entry.english.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('English: ${entry.english}'),
        ],
        if (entry.bisaya.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Bisaya: ${entry.bisaya}'),
        ],
        if (entry.topic.isNotEmpty || entry.module.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            [
              entry.module,
              entry.topic,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.gray),
          ),
        ],
        if (entry.variety.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Variety: ${entry.variety}'),
        ],
        if (entry.alternateForms.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Other forms: ${entry.alternateForms}'),
        ],
        if (entry.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(entry.notes),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              avatar: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(entry.reviewStatus),
            ),
            if (entry.source.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.source_outlined, size: 18),
                label: Text(entry.source),
              ),
          ],
        ),
      ],
    ),
  );
}
