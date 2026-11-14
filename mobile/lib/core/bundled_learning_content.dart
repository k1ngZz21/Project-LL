const bundledOfflineModuleKey = 'learnlite-offline-study-guide-v1';

const bundledOfflineModule = <String, dynamic>{
  'title': 'Offline Study Guide',
  'description': 'A practical guide to LearnLite’s offline tools. This is not an official Subanen language or cultural lesson and adds no vocabulary translations.',
  'is_published': true,
  'lessons': <Map<String, dynamic>>[
    {
      'index': 0,
      'title': 'Find workbook entries',
      'content': 'Open Offline Vocabulary Reference to search the vocabulary bundled with LearnLite. Use the source filters to distinguish the LearnLite workbook, starter list, and entries still needed. The vocabulary data keeps its source and review labels; being available offline does not mean an entry has been verified.',
      'keywords': ['offline', 'vocabulary', 'search'],
      'quiz': [
        {
          'question': 'Where can you search bundled workbook entries offline?',
          'choices': [
            'Offline Vocabulary Reference',
            'Firebase Authentication settings',
          ],
          'correct_answer_index': 0,
          'explanation': 'The Offline Vocabulary Reference reads the local SQLite vocabulary catalog.',
        },
      ],
    },
    {
      'index': 1,
      'title': 'Read source and review labels',
      'content': 'A vocabulary row retains its workbook source and review status. Treat those labels as part of the entry, and do not assume that an entry is verified simply because it appears in the app. This guide does not add or certify Subanen vocabulary.',
      'keywords': ['source', 'review status', 'verification'],
      'quiz': [
        {
          'question': 'What does an entry being available in LearnLite prove?',
          'choices': [
            'Only that the entry is stored in the local catalog',
            'That a fluent speaker has verified it',
          ],
          'correct_answer_index': 0,
          'explanation': 'The app preserves the source review status and does not infer verification from bundling.',
        },
      ],
    },
    {
      'index': 2,
      'title': 'Save study progress on this device',
      'content': 'Mark vocabulary as learned or bookmarked, open a lesson, and submit its quiz to save progress in SQLite. Saved lessons, quiz attempts, and progress remain on this device for the matching learner profile. A new Firebase login still requires Internet; LearnLite does not sync local progress to a remote service.',
      'keywords': ['SQLite', 'quiz', 'progress', 'offline'],
      'quiz': [
        {
          'question': 'Does a new Firebase login work without Internet?',
          'choices': [
            'Yes, Firebase login is available offline',
            'No, a new Firebase login requires Internet',
          ],
          'correct_answer_index': 1,
          'explanation': 'Previously saved learning content works offline; new Firebase authentication is not offline.',
        },
      ],
    },
  ],
};
