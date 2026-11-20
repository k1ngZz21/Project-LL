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

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({required this.gateway, super.key});

  final AdminGateway gateway;

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late Future<List<AdminModule>> _modulesFuture;
  late Future<AdminDashboardSummary> _summaryFuture;
  final List<_LessonEditor> _lessons = [];
  List<AdminModule> _modules = const [];
  int? _editingId;
  int? _uploadModuleId;
  int _uploadLessonIndex = 0;
  bool _isSaving = false;
  String? _errorMessage;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _modulesFuture = widget.gateway.fetchAdminModules();
    _summaryFuture = widget.gateway.fetchAdminSummary();
    _lessons.add(_LessonEditor());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final lesson in _lessons) {
      lesson.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _errorMessage = null;
      _modulesFuture = widget.gateway.fetchAdminModules();
      _summaryFuture = widget.gateway.fetchAdminSummary();
    });
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    for (final lesson in _lessons) {
      lesson.dispose();
    }
    _lessons
      ..clear()
      ..add(_LessonEditor());
    _editingId = null;
    _notice = null;
    _errorMessage = null;
  }

  void _editModule(AdminModule module) {
    for (final lesson in _lessons) {
      lesson.dispose();
    }
    _titleController.text = module.title;
    _descriptionController.text = module.description;
    _lessons
      ..clear()
      ..addAll(module.lessons.map(_LessonEditor.fromJson));
    if (_lessons.isEmpty) _lessons.add(_LessonEditor());
    setState(() {
      _editingId = module.id;
      _notice = null;
      _errorMessage = null;
      _uploadModuleId = module.id;
      _uploadLessonIndex = 0;
    });
  }

  Map<String, dynamic> _payload() {
    final lessons = _lessons.map((lesson) => lesson.toJson()).toList();
    return {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'lessons': lessons,
    };
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _notice = null;
    });
    try {
      final payload = _payload();
      if (_editingId == null) {
        await widget.gateway.createAdminModule(payload);
      } else {
        await widget.gateway.updateAdminModule(_editingId!, payload);
      }
      if (!mounted) return;
      _resetForm();
      _notice = 'Draft saved. Review the content before publishing it.';
      _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _togglePublication(AdminModule module) async {
    try {
      await widget.gateway.setModulePublished(module.id, !module.isPublished);
      if (mounted) {
        setState(
          () => _notice = module.isPublished
              ? 'Module unpublished.'
              : 'Module published and available to learners.',
        );
        _refresh();
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _deleteModule(AdminModule module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpublish this module?'),
        content: const Text(
          'The module will be removed from learners and offline downloads. Existing learner records are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.gateway.deleteAdminModule(module.id);
      if (_editingId == module.id && mounted) {
        setState(_resetForm);
      }
      if (mounted) _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _uploadResource() async {
    if (_uploadModuleId == null) {
      setState(
        () => _errorMessage = 'Select a saved module before uploading media.',
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'mp3',
        'wav',
        'ogg',
        'flac',
        'm4a',
        'mp4',
      ],
      withData: true,
    );
    if (picked == null) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _errorMessage = 'The selected file could not be read.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _notice = null;
    });
    try {
      final resource = await widget.gateway.uploadAdminResource(
        filename: file.name,
        bytes: bytes,
        moduleId: _uploadModuleId,
        lessonIndex: _uploadLessonIndex,
      );
      if (!mounted) return;
      setState(() => _notice = 'Uploaded ${resource.name}.');
      _refresh();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              error.message ?? 'The file could not be uploaded.',
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
              const SectionHeader(title: 'Upload Content'),
              const SizedBox(height: 8),
              Text(
                'Content is saved as a draft. Publish it only after confirming the source and review.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.gray),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _FeedbackBanner(message: _errorMessage!, isError: true),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _FeedbackBanner(message: _notice!, isError: false),
              ],
              const SizedBox(height: 18),
              _buildUploadControls(),
              const SizedBox(height: 18),
              _buildModuleForm(),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Learning Modules',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh module list',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              FutureBuilder<List<AdminModule>>(
                future: _modulesFuture,
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
                    return _FeedbackBanner(
                      message: userMessage(
                        snapshot.error,
                        fallback: 'This information could not be loaded.',
                      ),
                      isError: true,
                    );
                  }
                  _modules = snapshot.data ?? const [];
                  if (_modules.isEmpty) {
                    return const EmptyState(
                      icon: Icons.upload_file_outlined,
                      title: 'No modules uploaded',
                      message: 'Create a module using reviewed lesson content. No sample modules are provided.',
                    );
                  }
                  return Column(
                    children: [
                      for (final module in _modules) ...[
                        _ModuleAdminCard(
                          module: module,
                          onEdit: () => _editModule(module),
                          onPublish: () => _togglePublication(module),
                          onDelete: () => _deleteModule(module),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Recent uploads',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FutureBuilder<AdminDashboardSummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _FeedbackBanner(
                      message: userMessage(
                        snapshot.error,
                        fallback: 'This information could not be loaded.',
                      ),
                      isError: true,
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.recentUploads.isEmpty) {
                    return const Text('No files have been uploaded.');
                  }
                  return Column(
                    children: [
                      for (final upload in snapshot.data!.recentUploads)
                        ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(upload.name),
                          subtitle: Text(
                            '${upload.mediaType} · ${upload.sizeBytes} bytes',
                          ),
                        ),
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

  Widget _buildUploadControls() => LearnLiteCard(
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int>(
            initialValue: _modules.any((module) => module.id == _uploadModuleId)
                ? _uploadModuleId
                : null,
            decoration: const InputDecoration(
              labelText: 'Attach media to module',
            ),
            items: [
              for (final module in _modules)
                DropdownMenuItem(
                  value: module.id,
                  child: Text(module.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() {
              _uploadModuleId = value;
              _uploadLessonIndex = 0;
            }),
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<int>(
            initialValue:
                _uploadModuleId == null ||
                    _modules.every((module) => module.id != _uploadModuleId)
                ? null
                : _uploadLessonIndex,
            decoration: const InputDecoration(labelText: 'Lesson'),
            items: [
              if (_uploadLessonCount > 0)
                for (var index = 0; index < _uploadLessonCount; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Text('Lesson ${index + 1}'),
                  ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _uploadLessonIndex = value);
            },
          ),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _uploadResource,
          icon: const Icon(Icons.attach_file),
          label: const Text('Upload audio or image'),
        ),
      ],
    ),
  );

  Widget _buildModuleForm() => Form(
    key: _formKey,
    child: LearnLiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _editingId == null ? 'Create a module' : 'Edit module',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_editingId != null)
                TextButton(
                  onPressed: () => setState(_resetForm),
                  child: const Text('Cancel edit'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Module title'),
            validator: _requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: _requiredText,
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < _lessons.length; index++) ...[
            _LessonEditorCard(
              lesson: _lessons[index],
              index: index,
              canRemove: _lessons.length > 1,
              onRemove: () => setState(() {
                _lessons.removeAt(index).dispose();
              }),
              onRemoveQuestion: (questionIndex) => setState(
                () => _lessons[index].quizzes.removeAt(questionIndex).dispose(),
              ),
              onAddQuestion: () =>
                  setState(() => _lessons[index].quizzes.add(_QuizEditor())),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _lessons.add(_LessonEditor())),
              icon: const Icon(Icons.add),
              label: const Text('Add lesson'),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveModule,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_editingId == null ? 'Save draft' : 'Save changes'),
          ),
        ],
      ),
    ),
  );

  int get _uploadLessonCount {
    for (final module in _modules) {
      if (module.id == _uploadModuleId) return module.lessons.length;
    }
    return 0;
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
}

class _LessonEditor {
  _LessonEditor.fromJson(Map<String, dynamic> json)
    : title = TextEditingController(text: json['title'] as String?),
      content = TextEditingController(text: json['content'] as String?),
      phrase = TextEditingController(text: json['phrase'] as String?),
      pronunciation = TextEditingController(
        text: json['pronunciation'] as String?,
      ),
      audioUrl = TextEditingController(text: json['audio_url'] as String?),
      imageUrl = TextEditingController(text: json['image_url'] as String?),
      culturalNote = TextEditingController(
        text: json['cultural_note'] as String?,
      ),
      keywords = TextEditingController(
        text: ((json['keywords'] as List?) ?? const []).join(', '),
      ) {
    final quiz = json['quiz'];
    if (quiz is List) {
      quizzes.addAll(
        quiz.map((item) => _QuizEditor.fromJson(item as Map<String, dynamic>)),
      );
    }
  }

  _LessonEditor()
    : title = TextEditingController(),
      content = TextEditingController(),
      phrase = TextEditingController(),
      pronunciation = TextEditingController(),
      audioUrl = TextEditingController(),
      imageUrl = TextEditingController(),
      culturalNote = TextEditingController(),
      keywords = TextEditingController();

  final TextEditingController title;
  final TextEditingController content;
  final TextEditingController phrase;
  final TextEditingController pronunciation;
  final TextEditingController audioUrl;
  final TextEditingController imageUrl;
  final TextEditingController culturalNote;
  final TextEditingController keywords;
  final List<_QuizEditor> quizzes = [];

  Map<String, dynamic> toJson() => {
    'title': title.text.trim(),
    'content': content.text.trim(),
    'phrase': _nullable(phrase.text),
    'pronunciation': _nullable(pronunciation.text),
    'audio_url': _nullable(audioUrl.text),
    'image_url': _nullable(imageUrl.text),
    'cultural_note': _nullable(culturalNote.text),
    'keywords': keywords.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'quiz': quizzes
        .where((quiz) => quiz.question.text.trim().isNotEmpty)
        .map((quiz) => quiz.toJson())
        .toList(),
  };

  void dispose() {
    title.dispose();
    content.dispose();
    phrase.dispose();
    pronunciation.dispose();
    audioUrl.dispose();
    imageUrl.dispose();
    culturalNote.dispose();
    keywords.dispose();
    for (final quiz in quizzes) {
      quiz.dispose();
    }
  }
}

class _QuizEditor {
  _QuizEditor.fromJson(Map<String, dynamic> json)
    : question = TextEditingController(text: json['question'] as String?),
      choices = TextEditingController(
        text: ((json['choices'] as List?) ?? const []).join('\n'),
      ),
      answerIndex = TextEditingController(
        text: '${json['correct_answer_index'] ?? 0}',
      ),
      explanation = TextEditingController(text: json['explanation'] as String?);

  _QuizEditor()
    : question = TextEditingController(),
      choices = TextEditingController(),
      answerIndex = TextEditingController(text: '0'),
      explanation = TextEditingController();

  final TextEditingController question;
  final TextEditingController choices;
  final TextEditingController answerIndex;
  final TextEditingController explanation;

  Map<String, dynamic> toJson() {
    final answers = choices.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final index = int.tryParse(answerIndex.text.trim());
    if (answers.length < 2 ||
        answers.length > 6 ||
        index == null ||
        index < 0 ||
        index >= answers.length) {
      throw const FormatException(
        'Each quiz needs two to six choices and a valid zero-based answer index.',
      );
    }
    return {
      'question': question.text.trim(),
      'choices': answers,
      'correct_answer_index': index,
      'explanation': _nullable(explanation.text),
    };
  }

  void dispose() {
    question.dispose();
    choices.dispose();
    answerIndex.dispose();
    explanation.dispose();
  }
}

class _LessonEditorCard extends StatelessWidget {
  const _LessonEditorCard({
    required this.lesson,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onAddQuestion,
    required this.onRemoveQuestion,
  });

  final _LessonEditor lesson;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onAddQuestion;
  final ValueChanged<int> onRemoveQuestion;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: true,
    title: Text('Lesson ${index + 1}'),
    trailing: canRemove
        ? IconButton(
            tooltip: 'Remove lesson',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          )
        : const Icon(Icons.expand_more),
    childrenPadding: const EdgeInsets.all(12),
    children: [
      TextFormField(
        controller: lesson.title,
        decoration: const InputDecoration(labelText: 'Lesson title'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Lesson title is required.'
            : null,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.content,
        minLines: 3,
        maxLines: 8,
        decoration: const InputDecoration(labelText: 'Lesson content'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Lesson content is required.'
            : null,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.phrase,
        decoration: const InputDecoration(
          labelText: 'Verified phrase (optional)',
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.pronunciation,
        decoration: const InputDecoration(
          labelText: 'Pronunciation information (optional)',
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.audioUrl,
        decoration: const InputDecoration(
          labelText: 'HTTPS audio URL or uploaded resource path',
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.imageUrl,
        decoration: const InputDecoration(
          labelText: 'HTTPS image URL or uploaded resource path',
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.culturalNote,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Verified cultural note (optional)',
        ),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: lesson.keywords,
        decoration: const InputDecoration(
          labelText: 'Keywords (comma-separated, optional)',
        ),
      ),
      for (var index = 0; index < lesson.quizzes.length; index++) ...[
        const Divider(height: 24),
        _QuizEditorCard(
          quiz: lesson.quizzes[index],
          number: index + 1,
          onRemove: () => onRemoveQuestion(index),
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onAddQuestion,
          icon: const Icon(Icons.add),
          label: const Text('Add quiz question'),
        ),
      ),
    ],
  );
}

class _QuizEditorCard extends StatelessWidget {
  const _QuizEditorCard({
    required this.quiz,
    required this.number,
    required this.onRemove,
  });

  final _QuizEditor quiz;
  final int number;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text('Quiz question $number')),
          IconButton(
            tooltip: 'Remove question',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      TextField(
        controller: quiz.question,
        decoration: const InputDecoration(labelText: 'Question'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: quiz.choices,
        minLines: 2,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Answer choices',
          helperText: 'Enter one choice per line.',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: quiz.answerIndex,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Correct answer index (starts at 0)',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: quiz.explanation,
        decoration: const InputDecoration(labelText: 'Explanation (optional)'),
      ),
    ],
  );
}

class _ModuleAdminCard extends StatelessWidget {
  const _ModuleAdminCard({
    required this.module,
    required this.onEdit,
    required this.onPublish,
    required this.onDelete,
  });

  final AdminModule module;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
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
                module.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(
              label: Text(module.isPublished ? 'Published' : 'Draft'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Text(module.description),
        const SizedBox(height: 4),
        Text(
          '${module.lessons.length} lessons',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.gray),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            OutlinedButton(
              onPressed: onPublish,
              child: Text(module.isPublished ? 'Unpublish' : 'Publish'),
            ),
            IconButton(
              tooltip: 'Remove module from learners',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? AppColors.lightPink : AppColors.cream,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: isError ? AppColors.primary : Colors.green.shade800,
      ),
    ),
  );
}

String? _nullable(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
