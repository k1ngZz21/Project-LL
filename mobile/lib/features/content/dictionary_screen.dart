import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/loading_indicator.dart';
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
                const SectionHeader(
                  title: 'Search the dictionary',
                  subtitle: 'Bundled vocabulary is available offline.',
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.gray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Results come only from the bundled vocabulary workbooks. Entries marked "Pending review" have not been verified yet.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: IconBadge(
                              icon: Icons.arrow_forward_rounded,
                              tone: IconBadgeTone.dark,
                              size: 34,
                            ),
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
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LearnLiteButton(
                        onPressed: _isSearching ? null : _search,
                        isLoading: _isSearching,
                        icon: Icons.translate_rounded,
                        label: 'Search dictionary',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DictionaryLink(
                        icon: Icons.menu_book_rounded,
                        label: 'Browse vocabulary',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text(
                                  'Offline Vocabulary Reference',
                                ),
                                bottom: weaveAppBarBottom,
                              ),
                              body: SafeArea(
                                child: LocalVocabularyScreen(
                                  gateway: widget.gateway,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DictionaryLink(
                        icon: Icons.download_for_offline_rounded,
                        tone: IconBadgeTone.gold,
                        label: 'Offline content',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Offline Content Packs'),
                                bottom: weaveAppBarBottom,
                              ),
                              body: SafeArea(
                                child: OfflineContentScreen(
                                  gateway: widget.gateway,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_recentSearches.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionHeader(title: 'Recent searches'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final search in _recentSearches)
                        ActionChip(
                          avatar: const Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: AppColors.gray,
                          ),
                          label: Text(search),
                          onPressed: () => _search(search),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                if (_isSearching)
                  const LoadingCard(height: 140)
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
                    title: 'No matching entry found',
                    message: 'This word is not in the bundled vocabulary for the selected languages. No translation was generated.',
                  )
                else
                  const EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'Dictionary ready',
                    message: 'Search the bundled vocabulary. It works offline.',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.subanenWord,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                key: ValueKey(
                  entry.isVerified
                      ? 'dictionary-verified-${entry.id}'
                      : 'dictionary-pending-${entry.id}',
                ),
                icon: entry.isVerified
                    ? Icons.verified_rounded
                    : Icons.pending_outlined,
                label: entry.isVerified ? 'Verified' : 'Pending review',
                tone: entry.isVerified
                    ? IconBadgeTone.dark
                    : IconBadgeTone.gold,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 18,
                color: AppColors.gray,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.translation,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
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

class _DictionaryLink extends StatelessWidget {
  const _DictionaryLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = IconBadgeTone.red,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconBadgeTone tone;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        IconBadge(icon: icon, tone: tone, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: AppColors.primary));
}
