import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_colors.dart';
import '../../core/user_message.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/section_header.dart';
import '../auth/auth_gateway.dart';
import '../content/content_gateway.dart';

class AdminDictionaryScreen extends StatefulWidget {
  const AdminDictionaryScreen({required this.gateway, super.key});

  final AdminGateway gateway;

  @override
  State<AdminDictionaryScreen> createState() => _AdminDictionaryScreenState();
}

class _AdminDictionaryScreenState extends State<AdminDictionaryScreen> {
  final _searchController = TextEditingController();
  late Future<List<AdminDictionaryEntry>> _entriesFuture;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.gateway.fetchAdminDictionary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _errorMessage = null;
      _entriesFuture = widget.gateway.fetchAdminDictionary(
        query: _searchController.text,
      );
    });
  }

  Future<void> _editEntry([AdminDictionaryEntry? entry]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DictionaryEntryDialog(entry: entry),
    );
    if (result == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.saveDictionaryEntry(result, entryId: entry?.id);
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setActive(AdminDictionaryEntry entry, bool active) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.saveDictionaryEntry({
        'is_active': active,
      }, entryId: entry.id);
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEntry(AdminDictionaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove dictionary entry?'),
        content: const Text(
          'The entry will no longer appear in learner searches or offline packs. Its record will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.deactivateDictionaryEntry(entry.id);
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadAudio(AdminDictionaryEntry entry) async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'mp4'],
        withData: true,
      );
      if (selection == null) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _errorMessage = 'The selected audio could not be read.');
        return;
      }
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      await widget.gateway.uploadAdminResource(
        filename: file.name,
        bytes: bytes,
        vocabularyId: entry.id,
      );
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              error.message ?? 'The audio could not be uploaded.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Subanen Dictionary'),
              const SizedBox(height: 8),
              Text(
                'Entries remain hidden from learners until an administrator verifies the source.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _refresh(),
                      decoration: const InputDecoration(
                        hintText: 'Search dictionary entries',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Search dictionary',
                    onPressed: _refresh,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'Refresh dictionary',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : () => _editEntry(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add entry'),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _DictionaryFeedback(message: _errorMessage!, isError: true),
              ],
              const SizedBox(height: 12),
              FutureBuilder<List<AdminDictionaryEntry>>(
                future: _entriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _DictionaryFeedback(
                      message: userMessage(
                        snapshot.error,
                        fallback: 'Dictionary entries could not be loaded.',
                      ),
                      isError: true,
                    );
                  }
                  final entries = snapshot.data ?? const [];
                  if (entries.isEmpty) {
                    return const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No dictionary entries',
                      message: 'Imported or administrator-added records will appear here. Unverified entries stay private to administrators.',
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in entries) ...[
                        _DictionaryAdminCard(
                          entry: entry,
                          isSaving: _isSaving,
                          onEdit: () => _editEntry(entry),
                          onUploadAudio: () => _uploadAudio(entry),
                          onSetActive: () => _setActive(entry, !entry.isActive),
                          onDelete: () => _deleteEntry(entry),
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

class _DictionaryEntryDialog extends StatefulWidget {
  const _DictionaryEntryDialog({this.entry});

  final AdminDictionaryEntry? entry;

  @override
  State<_DictionaryEntryDialog> createState() => _DictionaryEntryDialogState();
}

class _DictionaryEntryDialogState extends State<_DictionaryEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _wordController;
  late final TextEditingController _englishController;
  late final TextEditingController _bisayaController;
  late final TextEditingController _pronunciationController;
  late final TextEditingController _moduleController;
  late final TextEditingController _topicController;
  late final TextEditingController _sourceController;
  late final TextEditingController _audioController;
  late bool _verified;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _wordController = TextEditingController(text: entry?.subanenWord);
    _englishController = TextEditingController(text: entry?.englishTranslation);
    _bisayaController = TextEditingController(text: entry?.bisayaTranslation);
    _pronunciationController = TextEditingController(
      text: entry?.pronunciation,
    );
    _moduleController = TextEditingController(text: entry?.module);
    _topicController = TextEditingController(text: entry?.topic);
    _sourceController = TextEditingController(text: entry?.source);
    _audioController = TextEditingController(text: entry?.audioUrl);
    _verified = entry?.isVerified ?? false;
  }

  @override
  void dispose() {
    _wordController.dispose();
    _englishController.dispose();
    _bisayaController.dispose();
    _pronunciationController.dispose();
    _moduleController.dispose();
    _topicController.dispose();
    _sourceController.dispose();
    _audioController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'subanen_word': _wordController.text.trim(),
      'english_translation': _englishController.text.trim(),
      'bisaya_translation': _nullable(_bisayaController.text),
      'pronunciation': _nullable(_pronunciationController.text),
      'module': _nullable(_moduleController.text),
      'topic': _nullable(_topicController.text),
      'source': _nullable(_sourceController.text),
      'audio_url': _nullable(_audioController.text),
      'is_verified': _verified,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Add dictionary entry' : 'Edit entry'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: 'Subanen word'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _englishController,
                decoration: const InputDecoration(
                  labelText: 'English translation',
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _bisayaController,
                decoration: const InputDecoration(
                  labelText: 'Cebuano translation (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pronunciationController,
                decoration: const InputDecoration(
                  labelText: 'Pronunciation information (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _moduleController,
                decoration: const InputDecoration(
                  labelText: 'Category or module (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Source or review citation',
                ),
                validator: (value) =>
                    _verified && (value == null || value.trim().isEmpty)
                    ? 'A source is required to verify this entry.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _audioController,
                decoration: const InputDecoration(
                  labelText: 'HTTPS audio URL or uploaded resource path',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _verified,
                title: const Text('Verified by administrator'),
                subtitle: const Text(
                  'Only verified active entries appear in learner searches.',
                ),
                onChanged: (value) =>
                    setState(() => _verified = value ?? false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class _DictionaryAdminCard extends StatelessWidget {
  const _DictionaryAdminCard({
    required this.entry,
    required this.isSaving,
    required this.onEdit,
    required this.onUploadAudio,
    required this.onSetActive,
    required this.onDelete,
  });

  final AdminDictionaryEntry entry;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onUploadAudio;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.subanenWord,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.primary),
              ),
            ),
            Chip(
              label: Text(
                !entry.isActive
                    ? 'Inactive'
                    : entry.isVerified
                    ? 'Verified'
                    : entry.reviewStatus ?? 'Pending review',
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Text(entry.englishTranslation),
        if (entry.pronunciation != null)
          Text('Pronunciation: ${entry.pronunciation}'),
        if (entry.topic != null || entry.module != null)
          Text(
            [entry.module, entry.topic]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
          ),
        if (entry.source != null)
          Text(
            'Source: ${entry.source}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          children: [
            TextButton.icon(
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            if (entry.isActive)
              TextButton.icon(
                onPressed: isSaving ? null : onUploadAudio,
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Upload audio'),
              ),
            if (!entry.isActive)
              TextButton(
                onPressed: isSaving ? null : onSetActive,
                child: const Text('Restore'),
              )
            else
              IconButton(
                tooltip: 'Remove from learner dictionary',
                onPressed: isSaving ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ],
    ),
  );
}

class _DictionaryFeedback extends StatelessWidget {
  const _DictionaryFeedback({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    backgroundColor: isError ? AppColors.lightPink : AppColors.cream,
    child: Text(
      message,
      style: TextStyle(color: isError ? AppColors.primary : AppColors.gray),
    ),
  );
}

String? _nullable(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
