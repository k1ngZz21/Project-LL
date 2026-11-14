import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import 'content_gateway.dart';
import 'local_vocabulary_screen.dart';
import 'offline_content_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({required this.gateway, super.key});

  final DictionaryGateway gateway;

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _queryController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  List<DictionaryTranslation> _results = const [];
  List<String> _recentSearches = const [];
  String _sourceLanguage = 'Subanen';
  String _targetLanguage = 'English';
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String? _playingError;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final searches = await widget.gateway.recentDictionarySearches();
      if (mounted) setState(() => _recentSearches = searches);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _search([String? query]) async {
    final value = (query ?? _queryController.text).trim();
    if (value.isEmpty) return;
    _queryController.text = value;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
      _results = const [];
    });
    try {
      final results = await widget.gateway.searchDictionary(
        value,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );
      await widget.gateway.recordDictionarySearch(value);
      final recent = await widget.gateway.recentDictionarySearches();
      if (mounted) {
        setState(() {
          _results = results;
          _recentSearches = recent;
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _playAudio(DictionaryEntry entry) async {
    final path = entry.audioUrl;
    if (path == null) return;
    setState(() => _playingError = null);
    try {
      final cached = await widget.gateway.cachedResource(path);
      if (cached != null) {
        await _audioPlayer.play(BytesSource(cached));
      } else if (path.startsWith('/resources/')) {
        await _audioPlayer.play(
          BytesSource(await widget.gateway.fetchResourceBytes(path)),
        );
      } else {
        await _audioPlayer.play(UrlSource(path));
      }
    } on Exception {
      if (mounted) {
        setState(() => _playingError = 'Audio is not available right now.');
      }
    }
  }

  List<String> get _targetLanguages => _sourceLanguage == 'Subanen'
      ? const ['English', 'Cebuano']
      : const ['Subanen'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'AI Search and Translator'),
                const SizedBox(height: 8),
                Text(
                  'Translations come only from verified dictionary records.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.gray),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Offline Vocabulary Reference'),
                          ),
                          body: SafeArea(
                            child: LocalVocabularyScreen(
                              gateway: widget.gateway,
                            ),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.offline_pin_outlined),
                    label: const Text('Browse workbook vocabulary offline'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.offline_pin_outlined,
                      size: 18,
                      color: AppColors.gray,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bundled vocabulary is available offline.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              OfflineContentScreen(gateway: widget.gateway),
                        ),
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Offline content'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LearnLiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _sourceLanguage,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'From',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Subanen',
                                  child: Text('Subanen'),
                                ),
                                DropdownMenuItem(
                                  value: 'English',
                                  child: Text('English'),
                                ),
                                DropdownMenuItem(
                                  value: 'Cebuano',
                                  child: Text('Cebuano'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _sourceLanguage = value;
                                  if (!_targetLanguages.contains(
                                    _targetLanguage,
                                  )) {
                                    _targetLanguage = _targetLanguages.first;
                                  }
                                  _hasSearched = false;
                                  _results = const [];
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.swap_horiz),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _targetLanguage,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'To',
                              ),
                              items: [
                                for (final language in _targetLanguages)
                                  DropdownMenuItem(
                                    value: language,
                                    child: Text(language),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _targetLanguage = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: const InputDecoration(
                          hintText: 'Enter a word or phrase',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSearching ? null : _search,
                        icon: const Icon(Icons.translate),
                        label: const Text('Search verified entries'),
                      ),
                    ],
                  ),
                ),
                if (_recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Recent searches',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final search in _recentSearches)
                        ActionChip(
                          label: Text(search),
                          onPressed: () => _search(search),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                if (_isSearching)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                else if (_errorMessage != null)
                  _ErrorMessage(message: _errorMessage!)
                else if (_results.isNotEmpty)
                  for (final result in _results) ...[
                    _DictionaryResultCard(
                      result: result,
                      onPlayAudio: () => _playAudio(result.entry),
                    ),
                    const SizedBox(height: 12),
                  ]
                else if (_hasSearched)
                  const EmptyState(
                    icon: Icons.search_off,
                    title: 'No verified translation found',
                    message: 'This entry is not in the available verified dictionary. No translation was generated.',
                  )
                else
                  const EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'Dictionary ready',
                    message: 'Search verified entries or download a dictionary pack for offline use.',
                  ),
                if (_playingError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _playingError!,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DictionaryResultCard extends StatelessWidget {
  const _DictionaryResultCard({
    required this.result,
    required this.onPlayAudio,
  });

  final DictionaryTranslation result;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    return LearnLiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.subanenWord,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.translation,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (entry.pronunciation != null) ...[
            const SizedBox(height: 10),
            Text('Pronunciation: ${entry.pronunciation}'),
          ],
          if (entry.definition != null) ...[
            const SizedBox(height: 10),
            Text(entry.definition!),
          ],
          if (entry.exampleSentence != null) ...[
            const SizedBox(height: 10),
            Text('Example: ${entry.exampleSentence}'),
          ],
          if (entry.topic != null || entry.module != null) ...[
            const SizedBox(height: 10),
            Text(
              [entry.module, entry.topic]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' · '),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.gray),
            ),
          ],
          if (entry.audioUrl != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Play recorded pronunciation',
                onPressed: onPlayAudio,
                icon: const Icon(Icons.volume_up_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: AppColors.primary));
}
