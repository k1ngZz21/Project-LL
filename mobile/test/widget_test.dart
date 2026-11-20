// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learnlite/core/avatar_design.dart';
import 'package:learnlite/core/learning_snapshot.dart';
import 'package:learnlite/features/auth/auth_gateway.dart';
import 'package:learnlite/features/auth/avatar_creation_screen.dart';
import 'package:learnlite/features/content/content_gateway.dart';
import 'package:learnlite/features/content/local_vocabulary.dart';
import 'package:learnlite/features/dashboard/progress_screen.dart';
import 'package:learnlite/features/modules/lesson_screen.dart';
import 'package:learnlite/features/profile/avatar_screen.dart';
import 'package:learnlite/features/settings/settings_screen.dart';
import 'package:learnlite/main.dart';

void main() {
  test('auth sessions default to unverified', () {
    expect(const AuthSession('test-session').emailVerified, isFalse);
  });

  test('empty snapshot starts without learner or learning data', () {
    const snapshot = LearningSnapshot.empty;

    expect(snapshot.fullName, isNull);
    expect(snapshot.username, isNull);
    expect(snapshot.avatarUrl, isNull);
    expect(snapshot.userLevel, 0);
    expect(snapshot.xp, 0);
    expect(snapshot.streak, 0);
    expect(snapshot.completedLessons, 0);
    expect(snapshot.learningModules, isEmpty);
    expect(snapshot.quizQuestions, isEmpty);
    expect(snapshot.badges, isEmpty);
    expect(snapshot.dictionaryEntries, isEmpty);
    expect(snapshot.certificates, isEmpty);
    expect(snapshot.recentSearches, isEmpty);
    expect(snapshot.downloadedContent, isEmpty);
  });

  testWidgets('dashboard shows empty content and zero progress', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('LearnLite'), findsOneWidget);
    expect(find.text('Welcome, Test Learner'), findsOneWidget);
    expect(find.text('No learning modules are available yet.'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));
    expect(find.text('Avery'), findsNothing);
    expect(find.text('Subanen word'), findsNothing);
  });

  testWidgets(
    'dashboard daily word keeps available translation labels honest',
    (WidgetTester tester) async {
      final gateway = _FakeDictionaryGateway(authenticated: true)
        ..catalogToReturn = const LocalVocabularyCatalog(
          vocabulary: [
            LocalVocabularyEntry(
              english: 'water',
              bisaya: 'tubig',
              subanen: 'sawa',
              module: 'Everyday words',
              topic: 'Nature',
              variety: '',
              alternateForms: '',
              source: 'Workbook',
              reviewStatus: 'Pending review',
              notes: '',
              sourceFile: 'workbook.xlsx',
              sourceRow: 1,
            ),
          ],
          starterList: [],
          stillNeeded: [],
          sourceRowCounts: {},
        );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
      await tester.pumpAndSettle();

      expect(find.text('Daily Word'), findsOneWidget);
      expect(find.text('sawa'), findsOneWidget);
      expect(find.text('water'), findsOneWidget);
      expect(find.text('Bisaya/Cebuano'), findsOneWidget);
      expect(find.text('Filipino'), findsOneWidget);
      expect(
        find.text('Translation not yet available in the vocabulary data.'),
        findsOneWidget,
      );
      expect(find.text('Pending review'), findsOneWidget);
    },
  );

  testWidgets('Continue Learning opens the saved unfinished lesson', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(authenticated: true)
      ..modulesToReturn = [_resumableModule]
      ..moduleToReturn = _resumableModule;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    final continueButton = find.widgetWithText(
      FilledButton,
      'Continue Learning',
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(gateway.startedLessonIndex, 1);
    expect(find.text('Everyday phrases'), findsOneWidget);
    expect(find.text('Lesson 2 of 2'), findsOneWidget);
  });

  testWidgets('navigation opens the empty dictionary state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeDictionaryGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('More tools'), findsNothing);
    await tester.tap(find.text('Lessons').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lessons-open-dictionary')));
    await tester.pumpAndSettle();

    expect(find.text('Search the dictionary'), findsOneWidget);
    expect(
      find.text(
        'Results come only from the bundled vocabulary workbooks. Entries marked "Pending review" have not been verified yet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Your learning journey'), findsNothing);
  });

  testWidgets('downloads navigation shows the empty offline-pack state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeDictionaryGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lessons').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lessons-open-downloads')));
    await tester.pumpAndSettle();

    expect(find.text('Offline Content Packs'), findsOneWidget);
    expect(find.text('No content packs available'), findsOneWidget);
    expect(
      find.textContaining('No learning modules are available'),
      findsNothing,
    );
  });

  testWidgets('system back on a secondary tab returns to Home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeDictionaryGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lessons').last);
    await tester.pumpAndSettle();
    expect(find.text('Learning Modules'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Learning Modules'), findsNothing);
    expect(find.text('Your learning snapshot'), findsOneWidget);
  });

  testWidgets('bottom navigation exposes Home Lessons Quiz Progress Profile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeDictionaryGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Quiz').last);
    await tester.pumpAndSettle();
    expect(find.text('Practice from your workbooks'), findsOneWidget);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Your learning progress'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('My Avatar'), findsOneWidget);

    await tester.tap(find.text('Lessons').last);
    await tester.pumpAndSettle();
    expect(find.text('Learning Modules'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets('wide layout keeps the mobile bottom navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('app bar opens AI Tutor and back returns to dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open AI Tutor'));
    await tester.pumpAndSettle();

    expect(find.text('AI Tutor'), findsOneWidget);
    expect(find.text('Learn with the AI Tutor'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('WELCOME BACK'), findsOneWidget);
  });

  testWidgets('new authenticated account opens empty avatar setup', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(
        authGateway: _FakeAuthGateway(
          authenticated: true,
          avatarCompleted: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Your Avatar'), findsOneWidget);
    expect(find.text('Avatar designs are coming soon'), findsNothing);
    expect(find.byKey(const ValueKey('profile-preview-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-preview')), findsOneWidget);
    expect(find.text('Start Learning'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-nickname')), findsOneWidget);
    expect(find.text('Design your avatar'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-gender-female')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-gender-male')), findsOneWidget);
  });

  testWidgets('avatar builder saves the drawn design and the nickname', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    LearnerProfile? savedProfile;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AvatarCreationScreen(
          profile: const LearnerProfile(
            username: 'test_user',
            fullName: 'Test Learner',
          ),
          authGateway: gateway,
          onSaved: (profile) => savedProfile = profile,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('profile-full-name')),
      'River Learner',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname')),
      'River',
    );
    expect(find.text('Avatar designs are coming soon'), findsNothing);
    Future<void> tapKey(String key) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await tapKey('avatar-gender-male');
    expect(find.text('Short'), findsOneWidget, reason: 'male hair styles');
    await tapKey('avatar-skin-4');
    await tapKey('avatar-hair-1');
    await tapKey('avatar-outfit-1');
    await tapKey('avatar-pattern-1');
    await tapKey('avatar-head-cloth');
    await tapKey('avatar-background-3');
    // The preview follows the choices.
    expect(find.bySemanticsLabel(RegExp('^Man avatar, deep skin')),
        findsWidgets);

    await tester.ensureVisible(find.text('Start Learning'));
    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();

    expect(savedProfile?.nickname, 'River');
    expect(savedProfile?.fullName, 'River Learner');
    expect(savedProfile?.avatarCompleted, isTrue);
    final saved = AvatarDesign.tryParse(savedProfile?.avatarId);
    expect(saved, isNotNull);
    expect(saved!.gender, AvatarGender.male);
    expect(saved.skinTone, 4);
    expect(saved.hairStyle, 1);
    expect(saved.outfitColor, 1);
    expect(saved.pattern, AvatarPattern.diamond);
    expect(saved.headCloth, isTrue);
    expect(saved.background, 3);
    expect(savedProfile?.outfitColor, saved.outfitHex);
  });

  testWidgets('starting learning saves profile and opens the dashboard', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(
      authenticated: true,
      avatarCompleted: false,
    );
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname')),
      'River',
    );
    await tester.ensureVisible(find.text('Start Learning'));
    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome, River'), findsOneWidget);
    expect(gateway.savedProfile?.nickname, 'River');
    expect(gateway.savedProfile?.avatarCompleted, isTrue);
  });

  testWidgets('login screen starts with empty email and password fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: _FakeAuthGateway()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(
      find.text('Downloaded learning works offline; sign-in needs Internet.'),
      findsOneWidget,
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller
          ?.text,
      isEmpty,
    );
    expect(_isObscured(tester, 'login-password'), isTrue);

    await tester.tap(
      find.byKey(const ValueKey('toggle-login-password-visibility')),
    );
    await tester.pump();
    expect(_isObscured(tester, 'login-password'), isFalse);
  });

  testWidgets(
    'registration starts with blank fields and no preference selected',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(LearnLiteApp(authGateway: _FakeAuthGateway()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 1'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Culture'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((chip) => !chip.selected),
        isTrue,
      );
      expect(_isObscured(tester, 'registration-password'), isTrue);
      expect(_isObscured(tester, 'registration-confirm-password'), isTrue);
      await tester.tap(
        find.byKey(const ValueKey('toggle-registration-password-visibility')),
      );
      await tester.pump();
      expect(_isObscured(tester, 'registration-password'), isFalse);
      expect(_isObscured(tester, 'registration-confirm-password'), isTrue);
      expect(find.byType(Checkbox), findsOneWidget);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller?.text, isEmpty);
      }
    },
  );

  testWidgets('login rejects missing credentials without attempting sign-in', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(gateway.signInAttempts, 0);
  });

  testWidgets('login rejects malformed email before attempting sign-in', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('login-username')),
      'not-an-email@',
    );
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'x');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(gateway.signInAttempts, 0);
  });

  testWidgets('password reset sends the requested email and confirms safely', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-email')),
      'learner@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();

    expect(gateway.passwordResetEmails, ['learner@example.com']);
    expect(
      find.text(
        'If an account matches that email, a password reset link is on its way.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings changes password after validating all fields', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            gateway: gateway,
            profile: const LearnerProfile(
              username: 'test_user',
              fullName: 'Test Learner',
            ),
            accountEmail: 'learner@example.test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-change-password')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current password.'), findsOneWidget);
    expect(gateway.passwordChangeAttempts, 0);

    await tester.enterText(
      find.byKey(const ValueKey('current-password')),
      'Current123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'BetterPassword123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-new-password')),
      'BetterPassword123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(gateway.passwordChangeAttempts, 1);
    expect(gateway.lastCurrentPassword, 'Current123');
    expect(gateway.lastNewPassword, 'BetterPassword123');
    expect(find.text('Your password has been updated.'), findsOneWidget);
  });

  testWidgets('signing out from Settings closes the Settings page', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    var signOutCalls = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarScreen(
            profile: const LearnerProfile(
              username: 'test_user',
              fullName: 'Test Learner',
            ),
            gateway: gateway,
            onSignOut: () async => signOutCalls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings & account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings & account'));
    await tester.pumpAndSettle();

    final signOut = find.byKey(const ValueKey('settings-sign-out'));
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(signOutCalls, 1);
    expect(signOut, findsNothing);
    expect(find.text('My Avatar'), findsOneWidget);
  });

  testWidgets('unverified email accounts are held at email verification', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(
      authenticated: true,
      email: 'learner@example.com',
      emailVerified: false,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.textContaining('learner@example.com'), findsOneWidget);
    expect(gateway.profileFetches, 0);

    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsNothing);
    expect(find.text('Welcome, Test Learner'), findsOneWidget);
    expect(gateway.profileFetches, 1);
  });

  testWidgets('unverified accounts remain restricted when Firebase says no', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(
      authenticated: true,
      email: 'learner@example.com',
      emailVerified: false,
      verificationResult: false,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Welcome, Test Learner'), findsNothing);
    expect(gateway.profileFetches, 0);
    expect(
      find.text(
        'Your email is not verified yet. Open the link in your inbox, then try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('verification email failures are shown without raw exceptions', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(
      authenticated: true,
      email: 'learner@example.com',
      emailVerified: false,
      verificationFailure: const AuthFailure(
        'Could not reach Firebase. Check your Internet connection and try again.',
        isOffline: true,
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();

    expect(gateway.resendAttempts, 1);
    expect(
      find.text(
        'Could not reach Firebase. Check your Internet connection and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('learners can request another verification email', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway(
      authenticated: true,
      email: 'learner@example.com',
      emailVerified: false,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend verification email'));
    await tester.pumpAndSettle();

    expect(gateway.resendAttempts, 1);
    expect(
      find.text('A new verification email has been sent.'),
      findsOneWidget,
    );
  });

  testWidgets('modules navigation shows a truthful empty state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lessons'));
    await tester.pumpAndSettle();

    expect(find.text('Learning Modules'), findsOneWidget);
    expect(find.text('No learning modules yet'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Module 1'), findsNothing);
  });

  testWidgets('rewards page starts with no earned badges or certificates', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Badges & certificates'));
    await tester.tap(find.text('Badges & certificates'));
    await tester.pumpAndSettle();

    expect(find.text('Badges & Certificates'), findsOneWidget);
    expect(find.text('0 of 4 earned'), findsOneWidget);
    expect(find.text('No certificates yet'), findsOneWidget);
    expect(
      find.text(
        'Complete every lesson in a published module to earn a completion certificate.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('First Steps'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Progress: 0 of 1'), findsOneWidget);
  });

  testWidgets('profile offers avatar creation and shows the saved avatar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeAuthGateway(authenticated: true);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('My Avatar'), findsOneWidget);
    expect(find.text('Outfits are locked'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('customize-avatar')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.text('Create your avatar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize-avatar')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('avatar-gender-male')));
    await tester.tap(find.byKey(const ValueKey('avatar-gender-male')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(
      AvatarDesign.tryParse(gateway.savedProfile?.avatarId)?.gender,
      AvatarGender.male,
    );
    await tester.scrollUntilVisible(
      find.text('Your avatar'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Your avatar'), findsOneWidget);
    expect(find.text('Customize avatar'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Man avatar')), findsWidgets);
    expect(find.text('Current level'), findsOneWidget);
    expect(find.text('Badges earned'), findsOneWidget);
  });

  testWidgets('dashboard displays data-backed empty daily quest and chest', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LearnLiteApp(authGateway: _FakeAuthGateway(authenticated: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Quests'), findsOneWidget);
    expect(find.text('Complete a lesson today'), findsOneWidget);
    expect(find.text('Weekly learning chest'), findsOneWidget);
    expect(find.text('0 of 1 lessons'), findsOneWidget);
    expect(find.text('0 of 5 lessons this week'), findsOneWidget);
    expect(find.text('+5 XP earned'), findsNothing);
    expect(find.text('+25 XP earned'), findsNothing);
  });

  testWidgets('progress shows saved quiz scores and answer review', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    const lesson = ModuleLesson(
      index: 0,
      title: 'Lesson One',
      content: 'Lesson content.',
      completed: true,
      quiz: [
        QuizQuestion(
          question: 'Which answer is correct?',
          choices: ['Wrong', 'Right'],
        ),
      ],
    );
    gateway.modulesToReturn = const [
      LearningModule(
        id: 4,
        title: 'Everyday phrases',
        description: 'Lesson module.',
        lessonCount: 1,
        completedLessons: 1,
        lessons: [lesson],
      ),
    ];
    gateway.quizAttemptsToReturn.add(
      QuizResult(
        attemptId: 7,
        score: 80,
        totalQuestions: 5,
        correctAnswers: 4,
        incorrectAnswers: 1,
        completedAt: DateTime.utc(2026, 5, 1),
        questions: const [
          QuizResultQuestion(
            question: 'Which answer is correct?',
            choices: ['Wrong', 'Right'],
            selectedAnswerIndex: 0,
            correctAnswerIndex: 1,
          ),
        ],
      ),
    );
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressScreen(
            snapshot: LearningSnapshot.empty,
            gateway: gateway,
            onOpenRewards: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quiz history'), findsOneWidget);
    expect(find.text('Everyday phrases · Lesson One'), findsOneWidget);
    expect(find.textContaining('80% · 4 of 5 correct'), findsOneWidget);
    await tester.ensureVisible(find.text('Everyday phrases · Lesson One'));
    await tester.tap(find.text('Everyday phrases · Lesson One'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Correct answer: Right'), findsOneWidget);
  });

  testWidgets('lesson without supplied enrichments stays text-only', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ModuleLessonScreen(
          gateway: gateway,
          module: const LearningModule(
            id: 1,
            title: 'Uploaded module title',
            description: 'Uploaded module description',
            lessonCount: 1,
            completedLessons: 0,
            lessons: [
              ModuleLesson(
                index: 0,
                title: 'Uploaded lesson title',
                content: 'Uploaded lesson content only.',
                completed: false,
              ),
            ],
          ),
          lesson: const ModuleLesson(
            index: 0,
            title: 'Uploaded lesson title',
            content: 'Uploaded lesson content only.',
            completed: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uploaded lesson content only.'), findsOneWidget);
    expect(find.text('Start Quiz'), findsNothing);
    expect(find.text('Subanen word'), findsNothing);
    expect(find.text('Cultural note'), findsNothing);
    expect(find.text('Pronunciation:'), findsNothing);
  });

  testWidgets(
    'lesson previous and next buttons navigate and save resume index',
    (WidgetTester tester) async {
      final gateway = _FakeAuthGateway();
      const first = ModuleLesson(
        index: 0,
        title: 'First lesson',
        content: 'First lesson content.',
        completed: false,
      );
      const second = ModuleLesson(
        index: 1,
        title: 'Second lesson',
        content: 'Second lesson content.',
        completed: false,
      );
      final module = LearningModule(
        id: 8,
        title: 'Test module',
        description: 'Navigation test',
        lessonCount: 2,
        completedLessons: 0,
        lessons: const [first, second],
      );
      gateway.moduleToReturn = module;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ModuleLessonScreen(
            gateway: gateway,
            module: module,
            lesson: first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Lesson'));
      await tester.pumpAndSettle();
      expect(find.text('Second lesson content.'), findsOneWidget);
      expect(gateway.startedLessonIndex, 1);

      await tester.tap(find.text('Previous Lesson'));
      await tester.pumpAndSettle();
      expect(find.text('First lesson content.'), findsOneWidget);
      expect(gateway.startedLessonIndex, 0);
    },
  );

  testWidgets('quiz selection submits and reviews actual server results', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lesson = ModuleLesson(
      index: 0,
      title: 'Administrator-provided title',
      content: 'Administrator-provided lesson text.',
      completed: false,
      phrase: 'Administrator-provided phrase',
      pronunciation: 'Administrator-provided guide',
      culturalNote: 'Administrator-provided cultural note.',
      keywords: const ['Administrator-provided keyword'],
      quiz: const [
        QuizQuestion(
          question: 'Administrator-provided question?',
          choices: ['Administrator choice one', 'Administrator choice two'],
        ),
      ],
    );
    final module = LearningModule(
      id: 7,
      title: 'Administrator-provided module',
      description: 'Administrator-provided description',
      lessonCount: 1,
      completedLessons: 0,
      lessons: [lesson],
    );
    gateway.moduleToReturn = module;
    gateway.quizResultToReturn = QuizResult(
      attemptId: 14,
      // Local SQLite results store the score as a percentage.
      score: 100,
      totalQuestions: 1,
      correctAnswers: 1,
      incorrectAnswers: 0,
      xpAwarded: 1,
      lessonXpAwarded: 10,
      totalXpAwarded: 11,
      previousLevel: 0,
      currentLevel: 0,
      completedAt: DateTime.utc(2026, 11, 3),
      questions: const [
        QuizResultQuestion(
          question: 'Administrator-provided question?',
          choices: ['Administrator choice one', 'Administrator choice two'],
          selectedAnswerIndex: 1,
          correctAnswerIndex: 1,
          explanation: 'Administrator-provided explanation.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ModuleLessonScreen(
          gateway: gateway,
          module: module,
          lesson: lesson,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrator-provided phrase'), findsOneWidget);
    expect(
      find.text('Pronunciation: Administrator-provided guide'),
      findsOneWidget,
    );
    expect(find.text('Administrator-provided cultural note.'), findsOneWidget);
    expect(find.text('Administrator-provided keyword'), findsOneWidget);
    await tester.tap(find.text('Start Quiz'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.textContaining('Earn 1 XP per correct answer'),
    );
    expect(find.text('Administrator-provided question?'), findsOneWidget);
    expect(find.textContaining('Earn 1 XP per correct answer'), findsOneWidget);

    await tester.tap(find.text('Check Answer'));
    await tester.pumpAndSettle();
    expect(find.text('Select one answer for every question.'), findsOneWidget);
    expect(gateway.quizSubmissions, 0);

    await tester.ensureVisible(find.text('Administrator choice two'));
    await tester.tap(find.text('Administrator choice two'));
    await tester.tap(find.text('Check Answer'));
    await tester.pumpAndSettle();

    expect(gateway.quizSubmissions, 1);
    expect(gateway.lastQuizAnswers, [1]);
    expect(find.text('Quiz complete'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('100 / 1'), findsNothing);
    expect(find.text('correct answers · 100%'), findsOneWidget);
    expect(find.text('+11 XP'), findsOneWidget);
    expect(find.text('Quiz XP: +1'), findsOneWidget);
    expect(find.text('Lesson completion XP: +10'), findsOneWidget);
    expect(find.textContaining('Level up!'), findsNothing);
    expect(find.textContaining('Outfit rewards are unavailable'), findsNothing);

    await tester.ensureVisible(find.text('Review Answers'));
    await tester.tap(find.text('Review Answers'));
    await tester.pumpAndSettle();
    expect(find.text('Administrator-provided explanation.'), findsOneWidget);
    expect(find.textContaining('Administrator choice two'), findsWidgets);
    expect(find.text('Administrator choice one'), findsNothing);

    // System Back on the results returns to the lesson page, not out of it.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quiz complete'), findsNothing);
    expect(find.text('Administrator-provided phrase'), findsOneWidget);
    expect(find.text('Start Quiz'), findsNothing);
    expect(find.text('Retake Quiz'), findsOneWidget);
  });

  testWidgets('starting a quiz after scrolling a long lesson shows question 1', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lesson = ModuleLesson(
      index: 0,
      title: 'Long lesson',
      content: List.generate(80, (i) => 'Lesson line $i.').join('\n'),
      completed: false,
      quiz: const [
        QuizQuestion(question: 'First question?', choices: ['One', 'Two']),
        QuizQuestion(question: 'Second question?', choices: ['Three', 'Four']),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ModuleLessonScreen(
          gateway: _FakeAuthGateway(),
          module: LearningModule(
            id: 3,
            title: 'Module',
            description: 'Description',
            lessonCount: 1,
            completedLessons: 0,
            lessons: [lesson],
          ),
          lesson: lesson,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Lesson line 0.'), findsNothing,
        reason: 'the lesson was scrolled down');

    await tester.tap(find.text('Start Quiz'));
    await tester.pumpAndSettle();
    final question = find.textContaining('Question 1 of 2');
    expect(question, findsOneWidget);
    expect(tester.getRect(question).top, lessThan(800),
        reason: 'question 1 is on screen, not scrolled past');
  });

  testWidgets('registration rejects required fields before account creation', (
    WidgetTester tester,
  ) async {
    final gateway = _FakeAuthGateway();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(LearnLiteApp(authGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Account').last);
    await tester.tap(find.text('Create Account').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Choose a username.'), findsOneWidget);
    expect(find.text('Create a password.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);
    expect(gateway.registrationAttempts, 0);
  });
}

bool _isObscured(WidgetTester tester, String fieldKey) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(fieldKey)),
        matching: find.byType(EditableText),
      ),
    )
    .obscureText;

const _resumableModule = LearningModule(
  id: 1,
  title: 'Everyday Subanen',
  description: 'Learn useful everyday phrases.',
  lessonCount: 2,
  completedLessons: 1,
  lastLessonIndex: 0,
  lessons: [
    ModuleLesson(
      index: 0,
      title: 'Greetings',
      content: 'A greeting lesson.',
      completed: true,
    ),
    ModuleLesson(
      index: 1,
      title: 'Everyday phrases',
      content: 'Practice everyday phrases.',
      completed: false,
    ),
  ],
);

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({
    this.authenticated = false,
    this.avatarCompleted = true,
    this.email,
    this.emailVerified = true,
    this.verificationResult = true,
    this.verificationFailure,
  });

  final bool authenticated;
  final bool avatarCompleted;
  final String? email;
  final bool emailVerified;
  final bool verificationResult;
  final AuthFailure? verificationFailure;
  LearnerProfile? savedProfile;
  LearningModule? moduleToReturn;
  List<LearningModule> modulesToReturn = const [];
  int? startedLessonIndex;
  QuizResult? quizResultToReturn;
  int quizSubmissions = 0;
  int profileFetches = 0;
  List<int>? lastQuizAnswers;
  final List<QuizResult> quizAttemptsToReturn = [];
  final List<String> passwordResetEmails = [];
  int passwordChangeAttempts = 0;
  String? lastCurrentPassword;
  String? lastNewPassword;
  int resendAttempts = 0;

  @override
  Stream<AuthSession?> get authStateChanges => Stream.value(
    authenticated
        ? AuthSession(
            'test-session',
            email: email,
            emailVerified: emailVerified,
          )
        : null,
  );

  @override
  bool get isConfigured => true;

  @override
  String? get initializationError => null;

  @override
  Future<bool> isUsernameAvailable(String username) async => true;

  @override
  Future<LearnerProfile> fetchProfile() async {
    profileFetches++;
    return LearnerProfile(
      username: 'test_user',
      fullName: 'Test Learner',
      avatarCompleted: avatarCompleted,
    );
  }

  @override
  Future<LearnerProfile> updateAvatarProfile(LearnerProfile profile) async {
    savedProfile = profile;
    return profile;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChangeAttempts++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
  }

  @override
  Future<List<LearningModule>> fetchModules({String search = ''}) async =>
      modulesToReturn;

  @override
  Future<LearningModule> fetchModule(int moduleId) async =>
      moduleToReturn ?? (throw const AuthFailure('Not found.'));

  @override
  Future<LearningModule> startModuleLesson(
    int moduleId,
    int lessonIndex,
  ) async {
    startedLessonIndex = lessonIndex;
    return moduleToReturn ?? (throw const AuthFailure('Not found.'));
  }

  @override
  Future<LearningModule> completeModuleLesson(
    int moduleId,
    int lessonIndex,
  ) async => moduleToReturn ?? (throw const AuthFailure('Not found.'));

  @override
  Future<QuizResult> submitLessonQuiz(
    int moduleId,
    int lessonIndex,
    List<int> answers,
  ) async {
    quizSubmissions++;
    lastQuizAnswers = answers;
    return quizResultToReturn ??
        (throw const AuthFailure('Quiz result unavailable.'));
  }

  @override
  Future<List<QuizResult>> fetchLessonQuizAttempts(
    int moduleId,
    int lessonIndex,
  ) async => quizAttemptsToReturn;

  @override
  Future<RewardsOverview> fetchRewards() async => _emptyRewardsOverview();

  @override
  Future<Uint8List> fetchCertificatePdf(String certificateId) async =>
      Uint8List(0);

  @override
  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String learningPreference,
  }) async {
    registrationAttempts++;
  }

  int signInAttempts = 0;
  int registrationAttempts = 0;

  @override
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    signInAttempts++;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetEmails.add(email);
  }

  @override
  Future<void> resendVerificationEmail() async {
    resendAttempts++;
    if (verificationFailure case final failure?) throw failure;
  }

  @override
  Future<bool> refreshEmailVerification() async {
    if (verificationFailure case final failure?) throw failure;
    return verificationResult;
  }
}

class _FakeDictionaryGateway extends _FakeAuthGateway
    implements DictionaryGateway {
  _FakeDictionaryGateway({super.authenticated});

  LocalVocabularyCatalog? catalogToReturn;
  final List<VocabularyQuizAttempt> vocabularyQuizAttempts = [];

  @override
  Future<LocalVocabularyCatalog> localVocabulary() async =>
      catalogToReturn ??
      const LocalVocabularyCatalog(
        vocabulary: [],
        starterList: [],
        stillNeeded: [],
        sourceRowCounts: {},
      );

  @override
  Future<void> setVocabularyLearningStatus({
    required int vocabularyId,
    required bool learned,
    required bool bookmarked,
  }) async {}

  @override
  Future<VocabularyQuizAttempt> saveVocabularyQuizAttempt({
    required String category,
    required List<VocabularyQuizResponse> responses,
  }) async {
    final attempt = VocabularyQuizAttempt(
      id: 'attempt-${vocabularyQuizAttempts.length + 1}',
      category: category,
      completedAt: DateTime.utc(2026, 1, 1),
      responses: List.unmodifiable(responses),
    );
    vocabularyQuizAttempts.add(attempt);
    return attempt;
  }

  @override
  Future<List<VocabularyQuizAttempt>> fetchVocabularyQuizAttempts() async =>
      List.unmodifiable(vocabularyQuizAttempts);

  @override
  Future<List<DictionaryTranslation>> searchDictionary(
    String query, {
    String sourceLanguage = 'Subanen',
    String targetLanguage = 'English',
  }) async => const [];

  @override
  Future<List<String>> recentDictionarySearches() async => const [];

  @override
  Future<void> recordDictionarySearch(String query) async {}

  @override
  Future<List<ContentPackDescriptor>> availableContentPacks() async => const [];

  @override
  Future<void> downloadContentPack(String id) async {}

  @override
  Future<void> removeContentPack(String id) async {}

  @override
  Future<List<ContentPackDescriptor>> downloadedContentPacks() async =>
      const [];

  @override
  Future<int> offlineStorageBytes() async => 0;

  @override
  Future<Uint8List?> cachedResource(String path) async => null;

  @override
  Future<Uint8List> fetchResourceBytes(String path) async => Uint8List(0);
}

RewardsOverview _emptyRewardsOverview() {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final monday = normalizedToday.subtract(
    Duration(days: normalizedToday.weekday - DateTime.monday),
  );
  return RewardsOverview(
    timezone: 'UTC',
    today: normalizedToday,
    streak: 0,
    longestStreak: 0,
    activeDates: const [],
    calendar: [
      for (var offset = 0; offset < 7; offset++)
        RewardCalendarDay(
          date: monday.add(Duration(days: offset)),
          weekday: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][offset],
          active: false,
          isToday: monday.add(Duration(days: offset)) == normalizedToday,
          isFuture: monday.add(Duration(days: offset)).isAfter(normalizedToday),
        ),
    ],
    dailyQuest: const DailyQuestStatus(
      title: 'Complete a lesson today',
      description: 'Finish one new lesson to earn the daily XP bonus.',
      progress: 0,
      target: 1,
      completed: false,
      xpReward: 5,
      xpAwarded: 0,
    ),
    weeklyChest: WeeklyChestStatus(
      title: 'Weekly learning chest',
      description: 'Complete five lessons this week to unlock the chest.',
      progress: 0,
      target: 5,
      unlocked: false,
      xpReward: 25,
      xpAwarded: 0,
      weekStart: monday,
    ),
    badges: const [
      RewardBadge(
        id: 'first_lesson',
        title: 'First Steps',
        description: 'Complete your first learning lesson.',
        earned: false,
        progress: 0,
        target: 1,
      ),
      RewardBadge(
        id: 'five_lessons',
        title: 'Learning Path',
        description: 'Complete five learning lessons.',
        earned: false,
        progress: 0,
        target: 5,
      ),
      RewardBadge(
        id: 'perfect_quiz',
        title: 'Perfect Recall',
        description: 'Earn a perfect score on a quiz.',
        earned: false,
        progress: 0,
        target: 1,
      ),
      RewardBadge(
        id: 'seven_day_streak',
        title: 'A Week of Learning',
        description: 'Learn on seven consecutive days.',
        earned: false,
        progress: 0,
        target: 7,
      ),
    ],
    certificates: const [],
  );
}
