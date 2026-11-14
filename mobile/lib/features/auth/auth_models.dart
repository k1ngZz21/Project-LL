import 'dart:typed_data';

class AuthSession {
  const AuthSession(this.uid, {this.email, this.emailVerified = false});

  final String uid;
  final String? email;
  final bool emailVerified;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => message;
}

class LearnerProfile {
  const LearnerProfile({
    required this.username,
    required this.fullName,
    this.nickname,
    this.avatarId,
    this.outfitColor,
    this.avatarCompleted = false,
    this.userLevel = 0,
    this.xp = 0,
    this.streak = 0,
    this.completedLessons = 0,
  });

  final String username;
  final String fullName;
  final String? nickname;
  final String? avatarId;
  final String? outfitColor;
  final bool avatarCompleted;
  final int userLevel;
  final int xp;
  final int streak;
  final int completedLessons;

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    final username = json['username'];
    final fullName = json['full_name'];
    if (username is! String || fullName is! String) {
      throw const FormatException('Learner profile fields are missing.');
    }
    return LearnerProfile(
      username: username,
      fullName: fullName,
      nickname: json['nickname'] as String?,
      avatarId: json['avatar_id'] as String?,
      outfitColor: json['outfit_color'] as String?,
      avatarCompleted: json['avatar_completed'] == true,
      userLevel: _intValue(json['user_level']),
      xp: _intValue(json['xp']),
      streak: _intValue(json['streak']),
      completedLessons: _intValue(json['completed_lessons']),
    );
  }

  Map<String, dynamic> toAvatarUpdate() => {
    'nickname': nickname,
    'avatar_id': avatarId,
    'outfit_color': outfitColor,
    'avatar_completed': avatarCompleted,
  };
}

class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.lessonCount,
    required this.completedLessons,
    this.lastLessonIndex,
    this.lessons = const [],
  });

  final int id;
  final String title;
  final String description;
  final int lessonCount;
  final int completedLessons;
  final int? lastLessonIndex;
  final List<ModuleLesson> lessons;

  factory LearningModule.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    if (id is! int || title is! String || description is! String) {
      throw const FormatException('Learning module fields are missing.');
    }
    final lessonsJson = json['lessons'];
    return LearningModule(
      id: id,
      title: title,
      description: description,
      lessonCount: _intValue(json['lesson_count']),
      completedLessons: _intValue(json['completed_lessons']),
      lastLessonIndex: json['last_lesson_index'] as int?,
      lessons: lessonsJson is List
          ? lessonsJson
                .map(
                  (lesson) =>
                      ModuleLesson.fromJson(lesson as Map<String, dynamic>),
                )
                .toList()
          : const [],
    );
  }

  LearningModule copyWith({
    int? completedLessons,
    int? lastLessonIndex,
    List<ModuleLesson>? lessons,
  }) => LearningModule(
    id: id,
    title: title,
    description: description,
    lessonCount: lessonCount,
    completedLessons: completedLessons ?? this.completedLessons,
    lastLessonIndex: lastLessonIndex ?? this.lastLessonIndex,
    lessons: lessons ?? this.lessons,
  );
}

class ModuleLesson {
  const ModuleLesson({
    required this.index,
    required this.title,
    required this.content,
    required this.completed,
    this.phrase,
    this.pronunciation,
    this.audioUrl,
    this.imageUrl,
    this.culturalNote,
    this.keywords = const [],
    this.quiz = const [],
  });

  final int index;
  final String title;
  final String content;
  final bool completed;
  final String? phrase;
  final String? pronunciation;
  final String? audioUrl;
  final String? imageUrl;
  final String? culturalNote;
  final List<String> keywords;
  final List<QuizQuestion> quiz;

  factory ModuleLesson.fromJson(Map<String, dynamic> json) {
    final index = json['index'];
    final title = json['title'];
    final content = json['content'];
    if (index is! int || title is! String || content is! String) {
      throw const FormatException('Module lesson fields are missing.');
    }
    return ModuleLesson(
      index: index,
      title: title,
      content: content,
      completed: json['completed'] == true,
      phrase: json['phrase'] as String?,
      pronunciation: json['pronunciation'] as String?,
      audioUrl: json['audio_url'] as String?,
      imageUrl: json['image_url'] as String?,
      culturalNote: json['cultural_note'] as String?,
      keywords: json['keywords'] is List
          ? (json['keywords'] as List).cast<String>()
          : const [],
      quiz: json['quiz'] is List
          ? (json['quiz'] as List)
                .map(
                  (question) =>
                      QuizQuestion.fromJson(question as Map<String, dynamic>),
                )
                .toList()
          : const [],
    );
  }

  ModuleLesson copyWith({bool? completed}) => ModuleLesson(
    index: index,
    title: title,
    content: content,
    completed: completed ?? this.completed,
    phrase: phrase,
    pronunciation: pronunciation,
    audioUrl: audioUrl,
    imageUrl: imageUrl,
    culturalNote: culturalNote,
    keywords: keywords,
    quiz: quiz,
  );
}

class QuizQuestion {
  const QuizQuestion({required this.question, required this.choices});

  final String question;
  final List<String> choices;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final question = json['question'];
    final choices = json['choices'];
    if (question is! String || choices is! List) {
      throw const FormatException('Quiz question fields are missing.');
    }
    return QuizQuestion(question: question, choices: choices.cast<String>());
  }
}

class QuizResultQuestion {
  const QuizResultQuestion({
    required this.question,
    required this.choices,
    required this.selectedAnswerIndex,
    required this.correctAnswerIndex,
    this.explanation,
  });

  final String question;
  final List<String> choices;
  final int selectedAnswerIndex;
  final int correctAnswerIndex;
  final String? explanation;

  factory QuizResultQuestion.fromJson(Map<String, dynamic> json) {
    final question = json['question'];
    final choices = json['choices'];
    final selected = json['selected_answer_index'];
    final correct = json['correct_answer_index'];
    if (question is! String ||
        choices is! List ||
        selected is! int ||
        correct is! int) {
      throw const FormatException('Quiz result fields are missing.');
    }
    return QuizResultQuestion(
      question: question,
      choices: choices.cast<String>(),
      selectedAnswerIndex: selected,
      correctAnswerIndex: correct,
      explanation: json['explanation'] as String?,
    );
  }
}

class QuizResult {
  const QuizResult({
    required this.attemptId,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    this.lessonXpAwarded = 0,
    this.totalXpAwarded = 0,
    required this.completedAt,
    required this.questions,
    this.module,
    this.xpAwarded,
    this.previousLevel,
    this.currentLevel,
  });

  final int attemptId;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final int? xpAwarded;
  final int lessonXpAwarded;
  final int totalXpAwarded;
  final int? previousLevel;
  final int? currentLevel;
  final DateTime completedAt;
  final List<QuizResultQuestion> questions;
  final LearningModule? module;

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    final attemptId = json['attempt_id'];
    final completedAt = json['completed_at'];
    final questions = json['questions'];
    if (attemptId is! int || completedAt is! String || questions is! List) {
      throw const FormatException('Quiz result fields are missing.');
    }
    return QuizResult(
      attemptId: attemptId,
      score: _intValue(json['score']),
      totalQuestions: _intValue(json['total_questions']),
      correctAnswers: _intValue(json['correct_answers']),
      incorrectAnswers: _intValue(json['incorrect_answers']),
      xpAwarded: json['xp_awarded'] as int?,
      lessonXpAwarded: _intValue(json['lesson_xp_awarded']),
      totalXpAwarded: _intValue(json['total_xp_awarded']),
      previousLevel: json['previous_level'] as int?,
      currentLevel: json['current_level'] as int?,
      completedAt: DateTime.parse(completedAt),
      module: json['module'] is Map<String, dynamic>
          ? LearningModule.fromJson(json['module'] as Map<String, dynamic>)
          : null,
      questions: questions
          .map(
            (question) =>
                QuizResultQuestion.fromJson(question as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class RewardBadge {
  const RewardBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.earned,
    required this.progress,
    required this.target,
    this.earnedAt,
  });

  final String id;
  final String title;
  final String description;
  final bool earned;
  final int progress;
  final int target;
  final DateTime? earnedAt;

  factory RewardBadge.fromJson(Map<String, dynamic> json) => RewardBadge(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    earned: json['earned'] == true,
    progress: _intValue(json['progress']),
    target: _intValue(json['target']),
    earnedAt: json['earned_at'] is String
        ? DateTime.parse(json['earned_at'] as String)
        : null,
  );
}

class RewardCalendarDay {
  const RewardCalendarDay({
    required this.date,
    required this.weekday,
    required this.active,
    required this.isToday,
    required this.isFuture,
  });

  final DateTime date;
  final String weekday;
  final bool active;
  final bool isToday;
  final bool isFuture;

  factory RewardCalendarDay.fromJson(Map<String, dynamic> json) =>
      RewardCalendarDay(
        date: DateTime.parse(json['activity_date'] as String),
        weekday: json['weekday'] as String,
        active: json['active'] == true,
        isToday: json['is_today'] == true,
        isFuture: json['is_future'] == true,
      );
}

class DailyQuestStatus {
  const DailyQuestStatus({
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.completed,
    required this.xpReward,
    required this.xpAwarded,
  });

  final String title;
  final String description;
  final int progress;
  final int target;
  final bool completed;
  final int xpReward;
  final int xpAwarded;

  factory DailyQuestStatus.fromJson(Map<String, dynamic> json) =>
      DailyQuestStatus(
        title: json['title'] as String,
        description: json['description'] as String,
        progress: _intValue(json['progress']),
        target: _intValue(json['target']),
        completed: json['completed'] == true,
        xpReward: _intValue(json['xp_reward']),
        xpAwarded: _intValue(json['xp_awarded']),
      );
}

class WeeklyChestStatus {
  const WeeklyChestStatus({
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.unlocked,
    required this.xpReward,
    required this.xpAwarded,
    required this.weekStart,
  });

  final String title;
  final String description;
  final int progress;
  final int target;
  final bool unlocked;
  final int xpReward;
  final int xpAwarded;
  final DateTime weekStart;

  factory WeeklyChestStatus.fromJson(Map<String, dynamic> json) =>
      WeeklyChestStatus(
        title: json['title'] as String,
        description: json['description'] as String,
        progress: _intValue(json['progress']),
        target: _intValue(json['target']),
        unlocked: json['unlocked'] == true,
        xpReward: _intValue(json['xp_reward']),
        xpAwarded: _intValue(json['xp_awarded']),
        weekStart: DateTime.parse(json['week_start'] as String),
      );
}

class LearnerCertificate {
  const LearnerCertificate({
    required this.certificateId,
    required this.moduleId,
    required this.moduleTitle,
    required this.learnerName,
    required this.issuedAt,
  });

  final String certificateId;
  final int moduleId;
  final String moduleTitle;
  final String learnerName;
  final DateTime issuedAt;

  factory LearnerCertificate.fromJson(Map<String, dynamic> json) =>
      LearnerCertificate(
        certificateId: json['certificate_id'] as String,
        moduleId: _intValue(json['module_id']),
        moduleTitle: json['module_title'] as String,
        learnerName: json['learner_name'] as String,
        issuedAt: DateTime.parse(json['issued_at'] as String),
      );
}

class RewardsOverview {
  const RewardsOverview({
    required this.timezone,
    required this.today,
    required this.streak,
    required this.longestStreak,
    required this.activeDates,
    required this.calendar,
    required this.dailyQuest,
    required this.weeklyChest,
    required this.badges,
    required this.certificates,
  });

  final String timezone;
  final DateTime today;
  final int streak;
  final int longestStreak;
  final List<DateTime> activeDates;
  final List<RewardCalendarDay> calendar;
  final DailyQuestStatus dailyQuest;
  final WeeklyChestStatus weeklyChest;
  final List<RewardBadge> badges;
  final List<LearnerCertificate> certificates;

  factory RewardsOverview.fromJson(Map<String, dynamic> json) =>
      RewardsOverview(
        timezone: json['timezone'] as String,
        today: DateTime.parse(json['today'] as String),
        streak: _intValue(json['streak']),
        longestStreak: _intValue(json['longest_streak']),
        activeDates: (json['active_dates'] as List)
            .map((value) => DateTime.parse(value as String))
            .toList(),
        calendar: (json['calendar'] as List)
            .map(
              (value) =>
                  RewardCalendarDay.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
        dailyQuest: DailyQuestStatus.fromJson(
          json['daily_quest'] as Map<String, dynamic>,
        ),
        weeklyChest: WeeklyChestStatus.fromJson(
          json['weekly_chest'] as Map<String, dynamic>,
        ),
        badges: (json['badges'] as List)
            .map((value) => RewardBadge.fromJson(value as Map<String, dynamic>))
            .toList(),
        certificates: (json['certificates'] as List)
            .map(
              (value) =>
                  LearnerCertificate.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
      );
}

int _intValue(dynamic value) => value is int ? value : 0;

abstract interface class AuthGateway {
  Stream<AuthSession?> get authStateChanges;
  bool get isConfigured;
  String? get initializationError;
  Future<bool> isUsernameAvailable(String username);
  Future<LearnerProfile> fetchProfile();
  Future<LearnerProfile> updateAvatarProfile(LearnerProfile profile);
  Future<List<LearningModule>> fetchModules({String search = ''});
  Future<LearningModule> fetchModule(int moduleId);
  Future<LearningModule> startModuleLesson(int moduleId, int lessonIndex);
  Future<LearningModule> completeModuleLesson(int moduleId, int lessonIndex);
  Future<QuizResult> submitLessonQuiz(
    int moduleId,
    int lessonIndex,
    List<int> answers,
  );
  Future<List<QuizResult>> fetchLessonQuizAttempts(
    int moduleId,
    int lessonIndex,
  );
  Future<RewardsOverview> fetchRewards();
  Future<Uint8List> fetchCertificatePdf(String certificateId);
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String learningPreference,
  });
  Future<void> signIn({required String username, required String password});
  Future<void> sendPasswordResetEmail(String email);
  Future<void> resendVerificationEmail();
  Future<bool> refreshEmailVerification();
  Future<void> signOut();
}
