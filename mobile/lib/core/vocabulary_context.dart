import '../features/content/local_vocabulary.dart';

/// Finds workbook entries that relate to a learner's Tutor question, so the
/// Tutor can quote real (pending-review) workbook data instead of guessing.
///
/// Matching is plain word overlap: the question is split into words of three
/// or more letters, and an entry scores one point for each of those words
/// that appears as a whole word in its English meaning or Subanen form.
/// Entries without both an English and a Subanen form are ignored. Results
/// are ordered by score, then by workbook order, and capped at [limit].
List<LocalVocabularyEntry> relevantVocabulary(
  String question,
  List<LocalVocabularyEntry> entries, {
  int limit = 8,
}) {
  final words = _words(question).where((word) => word.length >= 3).toSet()
    ..removeAll(_stopWords);
  if (words.isEmpty || limit <= 0) return const [];

  final scored = <({LocalVocabularyEntry entry, int score, int order})>[];
  final seen = <String>{};
  for (var order = 0; order < entries.length; order++) {
    final entry = entries[order];
    final english = entry.english.trim();
    final subanen = entry.subanen.trim();
    if (english.isEmpty || subanen.isEmpty) continue;
    if (!seen.add('${english.toLowerCase()}|${subanen.toLowerCase()}')) {
      continue;
    }
    final entryWords = {..._words(english), ..._words(subanen)};
    final score = words.where(entryWords.contains).length;
    if (score > 0) scored.add((entry: entry, score: score, order: order));
  }
  scored.sort(
    (a, b) => a.score != b.score
        ? b.score.compareTo(a.score)
        : a.order.compareTo(b.order),
  );
  return [for (final item in scored.take(limit)) item.entry];
}

/// The context payload sent to the Tutor for [entries].
List<Map<String, String>> tutorContext(List<LocalVocabularyEntry> entries) => [
  for (final entry in entries)
    {
      'english': entry.english.trim(),
      'subanen': entry.subanen.trim(),
      'status': entry.reviewStatus.trim().isEmpty
          ? 'Pending review'
          : entry.reviewStatus.trim(),
    },
];

Iterable<String> _words(String text) => RegExp(r"[a-z0-9']+")
    .allMatches(text.toLowerCase())
    .map((match) => match.group(0)!);

/// Common English words that would match too many entries to be useful.
const _stopWords = {
  'the', 'and', 'for', 'you', 'your', 'are', 'how', 'what', 'say', 'does',
  'did', 'can', 'mean', 'means', 'word', 'words', 'subanen', 'english',
  'translate', 'translation', 'with', 'this', 'that', 'from', 'into',
  'please', 'tell', 'about', 'there', 'they', 'them', 'have', 'has',
};
