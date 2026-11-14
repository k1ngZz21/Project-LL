class LearningSnapshot {
  const LearningSnapshot({
    this.fullName,
    this.username,
    this.nickname,
    this.avatarUrl,
    this.userLevel = 0,
    this.xp = 0,
    this.streak = 0,
    this.completedLessons = 0,
    this.learningModules = const [],
    this.quizQuestions = const [],
    this.badges = const [],
    this.dictionaryEntries = const [],
    this.certificates = const [],
    this.recentSearches = const [],
    this.downloadedContent = const [],
  });

  final String? fullName;
  final String? username;
  final String? nickname;
  final String? avatarUrl;
  final int userLevel;
  final int xp;
  final int streak;
  final int completedLessons;
  final List<Object> learningModules;
  final List<Object> quizQuestions;
  final List<Object> badges;
  final List<Object> dictionaryEntries;
  final List<Object> certificates;
  final List<Object> recentSearches;
  final List<Object> downloadedContent;

  static const empty = LearningSnapshot();
}
