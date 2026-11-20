// Account flows on a real Android device or emulator, against the local
// Firebase Auth emulator (never the production project).
//
// Run (see IMPLEMENTATION_NOTES.md "Device integration tests"):
//   firebase emulators:start --only auth --project demo-learnlite   (repo root)
//   flutter test integration_test/auth_flow_test.dart -d <device> \
//     --dart-define=LEARNLITE_AUTH_EMULATOR=10.0.2.2:9099
//
// Use a dedicated test AVD: the run installs LearnLite and writes to its
// local database.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:learnlite/core/learning_database.dart';
import 'package:learnlite/features/auth/auth_gateway.dart';

const _emulator = FirebaseAuthGateway.authEmulatorAddress;
const _password = 'Integration-Test-Pass-1';

Uri _emulatorUri(String path) => Uri.parse('http://$_emulator$path');

/// The emulator keeps accounts under the project it was started with
/// (`firebase emulators:start --project demo-learnlite`).
const _emulatorProject = String.fromEnvironment(
  'LEARNLITE_AUTH_EMULATOR_PROJECT',
  defaultValue: 'demo-learnlite',
);

Future<String> _projectId() async => _emulatorProject;

Future<void> _clearEmulatorAccounts() async {
  final project = await _projectId();
  await http.delete(
    _emulatorUri('/emulator/v1/projects/$project/accounts'),
  );
}

/// Opens the emulator's verification link for [email], as a learner would
/// by clicking the link in the verification email.
Future<void> _verifyEmail(String email) async {
  final project = await _projectId();
  final response = await http.get(
    _emulatorUri('/emulator/v1/projects/$project/oobCodes'),
  );
  final codes = (jsonDecode(response.body) as Map)['oobCodes'] as List;
  final code = codes.cast<Map>().lastWhere(
    (item) => item['email'] == email && item['requestType'] == 'VERIFY_EMAIL',
  );
  final link = Uri.parse(code['oobLink'] as String);
  // The link names the emulator as the PC sees it (127.0.0.1); the device
  // reaches it through the configured address instead.
  final reachable = link.replace(
    host: _emulator.split(':').first,
    port: int.parse(_emulator.split(':').last),
  );
  final applied = await http.get(reachable);
  expect(applied.statusCode, 200, reason: 'verification link applied');
}

Future<void> _deleteEmulatorAccount(String idToken) async {
  await http.post(
    _emulatorUri(
      '/identitytoolkit.googleapis.com/v1/accounts:delete?key=emulator',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'idToken': idToken}),
  );
}

Matcher _failure(String text) => isA<AuthFailure>().having(
  (failure) => failure.message,
  'message',
  contains(text),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthGateway gateway;
  late FirebaseAuth auth;
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'learner.a.$stamp@learnlite.test';
  final emailB = 'learner.b.$stamp@learnlite.test';

  setUpAll(() async {
    expect(
      _emulator,
      isNotEmpty,
      reason: 'Run with --dart-define=LEARNLITE_AUTH_EMULATOR=host:port',
    );
    gateway = await FirebaseAuthGateway.initialize() as FirebaseAuthGateway;
    expect(gateway.initializationError, isNull);
    auth = gateway.firebaseAuth!;
    await auth.signOut();
    await _clearEmulatorAccounts();
  });

  tearDownAll(() async {
    await auth.signOut();
  });

  test('register account A; it waits for email verification', () async {
    await gateway.register(
      fullName: 'Learner A',
      username: 'learner_a_$stamp',
      email: emailA,
      password: _password,
      learningPreference: 'Vocabulary',
    );
    final user = auth.currentUser!;
    expect(user.email, emailA);
    expect(user.emailVerified, isFalse);
    final session = await gateway.authStateChanges.first;
    expect(session?.emailVerified, isFalse);
    expect(
      await LearningDatabase.instance.learner(user.uid),
      isNotNull,
      reason: 'local SQLite profile created for the Firebase UID',
    );
    expect(
      gateway.tutorIdToken(),
      throwsA(_failure('Verify your email')),
    );
  });

  test('duplicate, invalid and weak registrations are refused', () async {
    await auth.signOut();
    await expectLater(
      gateway.register(
        fullName: 'Duplicate',
        username: 'dup_$stamp',
        email: emailA,
        password: _password,
        learningPreference: 'Vocabulary',
      ),
      throwsA(_failure('already uses this email')),
    );
    await expectLater(
      gateway.register(
        fullName: 'Invalid',
        username: 'invalid_$stamp',
        email: 'not-an-email',
        password: _password,
        learningPreference: 'Vocabulary',
      ),
      throwsA(_failure('valid email')),
    );
    await expectLater(
      gateway.register(
        fullName: 'Weak',
        username: 'weak_$stamp',
        email: 'weak.$stamp@learnlite.test',
        password: '123',
        learningPreference: 'Vocabulary',
      ),
      throwsA(_failure('stronger password')),
    );
    await expectLater(
      gateway.register(
        fullName: 'Same username',
        username: 'learner_a_$stamp',
        email: 'other.$stamp@learnlite.test',
        password: _password,
        learningPreference: 'Vocabulary',
      ),
      throwsA(_failure('username is already used')),
    );
  });

  test('wrong password, unknown email and username sign-in are refused',
      () async {
    await expectLater(
      gateway.signIn(username: emailA, password: 'wrong-password'),
      throwsA(_failure('Email or password is incorrect')),
    );
    await expectLater(
      gateway.signIn(
        username: 'nobody.$stamp@learnlite.test',
        password: _password,
      ),
      throwsA(_failure('Email or password is incorrect')),
    );
    await expectLater(
      gateway.signIn(username: 'learner_a_$stamp', password: _password),
      throwsA(_failure('email address')),
    );
    expect(auth.currentUser, isNull);
  });

  test('verified account A signs in, studies and keeps its progress',
      () async {
    await _verifyEmail(emailA);
    await gateway.signIn(username: emailA, password: _password);
    expect(auth.currentUser?.emailVerified, isTrue);
    expect(await gateway.tutorIdToken(), isNotEmpty);

    final modules = await gateway.fetchModules();
    expect(modules, isNotEmpty, reason: 'bundled and workbook modules');
    final module = modules.firstWhere(
      (item) => item.lessons.any((lesson) => lesson.quiz.isNotEmpty),
    );
    final lesson = module.lessons.firstWhere((item) => item.quiz.isNotEmpty);
    await gateway.startModuleLesson(module.id, lesson.index);
    final result = await gateway.submitLessonQuiz(
      module.id,
      lesson.index,
      List.filled(lesson.quiz.length, 0),
    );
    expect(result.totalQuestions, lesson.quiz.length);
    expect(result.correctAnswers + result.incorrectAnswers,
        result.totalQuestions);
    expect(result.score, inInclusiveRange(0, 100));

    final profile = await gateway.fetchProfile();
    expect(profile.xp, greaterThan(0));
    expect(
      await gateway.fetchLessonQuizAttempts(module.id, lesson.index),
      hasLength(1),
    );
  });

  test('logout keeps account A data; account B starts empty and isolated',
      () async {
    final uidA = auth.currentUser!.uid;
    final xpA = (await gateway.fetchProfile()).xp;
    await gateway.signOut();
    expect(auth.currentUser, isNull);
    expect(await gateway.authStateChanges.first, isNull);
    expect((await LearningDatabase.instance.learner(uidA))?['xp'], xpA,
        reason: 'signing out never deletes local progress');

    await gateway.register(
      fullName: 'Learner B',
      username: 'learner_b_$stamp',
      email: emailB,
      password: _password,
      learningPreference: 'Culture',
    );
    await _verifyEmail(emailB);
    await gateway.signOut();
    await gateway.signIn(username: emailB, password: _password);
    final uidB = auth.currentUser!.uid;
    expect(uidB, isNot(uidA));

    final profileB = await gateway.fetchProfile();
    expect(profileB.xp, 0);
    expect(profileB.completedLessons, 0);
    final modules = await gateway.fetchModules();
    for (final module in modules) {
      expect(module.completedLessons, 0,
          reason: 'B must not see A\'s progress in ${module.title}');
    }

    await gateway.signOut();
    await gateway.signIn(username: emailA, password: _password);
    expect((await gateway.fetchProfile()).xp, xpA,
        reason: 'A\'s progress is intact after B used the device');
  });

  test('a deleted account loses its session and returns to sign-in',
      () async {
    final token = await auth.currentUser!.getIdToken();
    await _deleteEmulatorAccount(token!);
    await expectLater(
      gateway.refreshEmailVerification(),
      throwsA(isA<AuthFailure>()),
    );
    expect(auth.currentUser, isNull,
        reason: 'Firebase signs out a user whose account no longer exists');
    expect(await gateway.authStateChanges.first, isNull);
  });

  test('sign-in without a reachable Firebase gives the offline message',
      () async {
    final offlineApp = await Firebase.initializeApp(
      name: 'offline-check',
      options: Firebase.app().options,
    );
    final offlineAuth = FirebaseAuth.instanceFor(app: offlineApp);
    // Nothing listens on port 9 of the PC, so every request fails like a
    // device without a network.
    await offlineAuth.useAuthEmulator(_emulator.split(':').first, 9);
    final offlineGateway = FirebaseAuthGateway(firebaseAuth: offlineAuth);
    await expectLater(
      offlineGateway.signIn(username: emailB, password: _password),
      throwsA(
        isA<AuthFailure>()
            .having((failure) => failure.isOffline, 'isOffline', isTrue)
            .having((failure) => failure.message, 'message',
                contains('Could not reach Firebase')),
      ),
    );
    await offlineApp.delete();
  });
}
