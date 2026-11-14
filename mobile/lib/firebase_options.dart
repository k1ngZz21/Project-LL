import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class FirebaseOptionsConfig {
  static const expectedProjectId = 'learnlite-f1dd5';
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: expectedProjectId,
  );
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static String? get configurationError {
    if (_projectId != expectedProjectId) {
      return 'Firebase project ID must be $expectedProjectId. Check the LearnLite build configuration.';
    }
    if (_apiKey.isEmpty || _appId.isEmpty || _messagingSenderId.isEmpty) {
      return 'Firebase Android client options are missing. Obtain the API key, Android app ID, and project number from Firebase Console for com.example.learnlite.';
    }
    if (kIsWeb && _authDomain.isEmpty) {
      return 'Firebase web auth domain is missing from the LearnLite configuration.';
    }
    return null;
  }

  static bool get isConfigured => configurationError == null;

  static bool matches(FirebaseOptions options) =>
      _projectId == expectedProjectId &&
      options.projectId == expectedProjectId &&
      (_apiKey.isEmpty || options.apiKey == _apiKey) &&
      (_appId.isEmpty || options.appId == _appId) &&
      (_messagingSenderId.isEmpty ||
          options.messagingSenderId == _messagingSenderId) &&
      (_authDomain.isEmpty || options.authDomain == _authDomain) &&
      (_iosBundleId.isEmpty || options.iosBundleId == _iosBundleId);

  static FirebaseOptions get current => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: expectedProjectId,
    authDomain: _authDomain.isEmpty ? null : _authDomain,
    iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
  );
}
