import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnlite/core/vocabulary_context.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:learnlite/features/tutor/tutor_gateway.dart';

LocalVocabularyEntry _entry(String english, String subanen, int row) =>
    LocalVocabularyEntry(
      english: english,
      bisaya: '',
      subanen: subanen,
      module: '1 · Basic Greetings',
      topic: 'Greetings by time of day',
      variety: '',
      alternateForms: '',
      source: '',
      reviewStatus: 'Pending review',
      notes: '',
      sourceFile: 'LearnLite-Subanen-Vocabulary.xlsx',
      sourceRow: row,
    );

void main() {
  final entries = [
    _entry('Good day', 'gempya gendao', 2),
    _entry('Good morning', 'gempya seselem', 3),
    _entry('Morning (time of day)', 'siselem', 4),
    _entry('Thank you', 'salamat', 5),
    _entry('Water', '', 6),
  ];

  test('finds entries by English or Subanen words, best match first', () {
    final result = relevantVocabulary('How do I say good morning?', entries);
    expect(result.map((e) => e.subanen), [
      'gempya seselem', // matches "good" and "morning"
      'gempya gendao', // matches "good"
      'siselem', // matches "morning"
    ]);
    expect(
      relevantVocabulary('What does salamat mean?', entries).single.english,
      'Thank you',
    );
  });

  test('ignores common words, incomplete pairs, and respects the limit', () {
    expect(relevantVocabulary('how do you say the word', entries), isEmpty);
    expect(relevantVocabulary('water', entries), isEmpty);
    expect(relevantVocabulary('good morning', entries, limit: 1).length, 1);
  });

  test('the Tutor request carries the context only when there is some',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final gateway = OllamaTutorGateway(
      idTokenProvider: () async => 'token',
      apiBaseUrl: 'http://127.0.0.1:8000',
      client: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'response': 'ok', 'model': 'qwen2.5:3b'}),
          200,
        );
      }),
    );
    const messages = [
      TutorMessage(role: TutorMessageRole.user, content: 'good morning'),
    ];
    await gateway.sendMessages(
      messages,
      context: tutorContext(relevantVocabulary('good morning', entries)),
    );
    await gateway.sendMessages(messages);

    expect(bodies.first['context'], [
      {
        'english': 'Good morning',
        'subanen': 'gempya seselem',
        'status': 'Pending review',
      },
      {
        'english': 'Good day',
        'subanen': 'gempya gendao',
        'status': 'Pending review',
      },
      {
        'english': 'Morning (time of day)',
        'subanen': 'siselem',
        'status': 'Pending review',
      },
    ]);
    expect(bodies.last.containsKey('context'), isFalse);
  });
}
