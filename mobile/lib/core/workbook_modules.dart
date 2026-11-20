import '../features/content/local_vocabulary.dart';

/// Builds LearnLite's language modules from the bundled workbook
/// (`LearnLite-Subanen-Vocabulary.xlsx`, exported as JSON).
///
/// Nothing here invents language content. Each workbook module becomes a
/// learning module, each of its topics becomes a lesson, and every quiz
/// question is made from that lesson's own workbook rows: the prompt is the
/// row's English meaning, the right answer is the row's Subanen form, and the
/// other choices are Subanen forms from other rows of the same module. The
/// only added text is fixed, factual wording ("This lesson lists N workbook
/// entries…") and each explanation cites the workbook row.
///
/// Generation is deterministic (no randomness), so the same workbook always
/// produces the same modules and a content change can be detected.

/// Bump when the way modules, lessons or quizzes are generated changes, so
/// devices regenerate the modules even if the workbook is unchanged.
const workbookModulesGeneratorVersion = 2;

/// Questions per lesson, at most.
const workbookQuizQuestionLimit = 5;

/// Choices per question, at most (one right answer plus distractors).
const workbookQuizChoiceLimit = 4;

/// The source file every generated lesson draws on.
const workbookSourceFile = 'LearnLite-Subanen-Vocabulary.xlsx';

/// A generated module and the stable key that identifies it on a device.
class WorkbookModuleSeed {
  const WorkbookModuleSeed({required this.key, required this.module});

  /// For example `workbook-module-1`; stays the same when content changes,
  /// so progress (stored by module ID and lesson index) is kept.
  final String key;

  /// A module map in the shape `LearningDatabase.saveModule` accepts.
  final Map<String, dynamic> module;
}

/// "1 · Basic Greetings" → "Basic Greetings". Names without a number prefix
/// are returned trimmed.
String workbookModuleName(String rawModule) {
  final match = RegExp(r'^\s*\d+\s*·\s*(.+)$').firstMatch(rawModule);
  return (match?.group(1) ?? rawModule).trim();
}

/// "1 · Basic Greetings" → 1; `null` when the name has no number prefix.
int? workbookModuleNumber(String rawModule) {
  final match = RegExp(r'^\s*(\d+)\s*·').firstMatch(rawModule);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Whether [entry] belongs to the lesson [lessonTitle] of the generated
/// module titled [moduleTitle]. Used to show a lesson's words.
bool isWorkbookLessonEntry(
  LocalVocabularyEntry entry, {
  required String moduleTitle,
  required String lessonTitle,
}) =>
    entry.sourceFile == workbookSourceFile &&
    workbookModuleName(entry.module) == moduleTitle.trim() &&
    entry.topic.trim() == lessonTitle.trim();

/// Builds one module per numbered workbook module, ordered by its number.
/// Rows without a numbered module or a topic are left to the dictionary and
/// practice screens.
List<WorkbookModuleSeed> buildWorkbookModules(
  List<LocalVocabularyEntry> vocabulary,
) {
  final byModule = <int, _ModuleRows>{};
  for (final entry in vocabulary) {
    if (entry.sourceFile != workbookSourceFile) continue;
    final number = workbookModuleNumber(entry.module);
    final topic = entry.topic.trim();
    if (number == null || topic.isEmpty) continue;
    final rows = byModule.putIfAbsent(
      number,
      () => _ModuleRows(workbookModuleName(entry.module)),
    );
    rows.topics.putIfAbsent(topic, () => []).add(entry);
  }

  final numbers = byModule.keys.toList()..sort();
  return [
    for (final number in numbers)
      WorkbookModuleSeed(
        key: 'workbook-module-$number',
        module: _buildModule(byModule[number]!),
      ),
  ];
}

class _ModuleRows {
  _ModuleRows(this.name);

  final String name;

  /// Topic name → rows, in workbook order (insertion order is kept).
  final Map<String, List<LocalVocabularyEntry>> topics = {};

  List<LocalVocabularyEntry> get all => [
    for (final rows in topics.values) ...rows,
  ];
}

Map<String, dynamic> _buildModule(_ModuleRows rows) {
  final entryCount = rows.all.length;
  final topicCount = rows.topics.length;
  final lessons = <Map<String, dynamic>>[];
  var index = 0;
  for (final topic in rows.topics.entries) {
    lessons.add(_buildLesson(index, topic.key, topic.value, rows));
    index++;
  }
  return {
    'title': rows.name,
    'description':
        '$entryCount workbook ${entryCount == 1 ? 'entry' : 'entries'} '
        'across $topicCount ${topicCount == 1 ? 'topic' : 'topics'}. '
        'Pending review by a fluent Subanen speaker.',
    'is_published': true,
    'lessons': lessons,
  };
}

Map<String, dynamic> _buildLesson(
  int index,
  String topic,
  List<LocalVocabularyEntry> entries,
  _ModuleRows module,
) {
  final count = entries.length;
  return {
    'index': index,
    'title': topic,
    'content':
        'This lesson lists the $count workbook '
        '${count == 1 ? 'entry' : 'entries'} for "$topic" in the '
        '${module.name} module. Study each word card below: the Subanen form, '
        'its English meaning and, where the workbook gives one, the '
        'Cebuano/Bisaya form. These entries are pending review by a fluent '
        'speaker, so treat them as workbook data rather than verified '
        'translations.',
    'keywords': <String>[],
    'quiz': _buildQuiz(entries, module.all),
  };
}

/// Up to [workbookQuizQuestionLimit] questions, spread evenly over the
/// lesson's rows. Each asks for the Subanen form of an English meaning.
List<Map<String, dynamic>> _buildQuiz(
  List<LocalVocabularyEntry> lessonRows,
  List<LocalVocabularyEntry> moduleRows,
) {
  final candidates = _distinctPairs(lessonRows);
  if (candidates.isEmpty) return const [];
  final picks = <LocalVocabularyEntry>[];
  if (candidates.length <= workbookQuizQuestionLimit) {
    picks.addAll(candidates);
  } else {
    for (var i = 0; i < workbookQuizQuestionLimit; i++) {
      picks.add(
        candidates[(i * candidates.length) ~/ workbookQuizQuestionLimit],
      );
    }
  }

  final pool = _distinctPairs(moduleRows);
  final quiz = <Map<String, dynamic>>[];
  for (var position = 0; position < picks.length; position++) {
    final question = picks[position];
    final answer = question.subanen.trim();
    final distractors = <String>[];
    final seen = {answer.toLowerCase()};
    // Rotate the starting point so questions draw different distractors.
    for (var step = 0; step < pool.length; step++) {
      final candidate =
          pool[(position * 3 + step) % pool.length].subanen.trim();
      if (seen.add(candidate.toLowerCase())) distractors.add(candidate);
      if (distractors.length == workbookQuizChoiceLimit - 1) break;
    }
    if (distractors.isEmpty) continue;
    // Place the right answer at a varying position, deterministically.
    final choices = [...distractors];
    final correctIndex = position % (distractors.length + 1);
    choices.insert(correctIndex, answer);
    quiz.add({
      'question':
          'Which Subanen form does the workbook give for '
          '"${question.english.trim()}"?',
      'choices': choices,
      'correct_answer_index': correctIndex,
      'explanation':
          'Workbook row ${question.sourceRow}: "${question.english.trim()}" '
          '→ $answer. ${question.reviewStatus.trim().isEmpty ? 'Pending review' : question.reviewStatus.trim()}.',
    });
  }
  return quiz;
}

/// Rows that have both an English and a Subanen form, one per Subanen form.
List<LocalVocabularyEntry> _distinctPairs(List<LocalVocabularyEntry> rows) {
  final seen = <String>{};
  return [
    for (final row in rows)
      if (row.english.trim().isNotEmpty &&
          row.subanen.trim().isNotEmpty &&
          seen.add(row.subanen.trim().toLowerCase()))
        row,
  ];
}
