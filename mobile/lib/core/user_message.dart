import 'app_log.dart';

import '../features/auth/auth_models.dart';
import 'offline_content_store.dart';

/// Turns an error into text that is safe to show a learner.
///
/// LearnLite's own failures already carry plain-language messages, so those
/// are shown as they are. Anything else (database, platform or programming
/// errors) is replaced by [fallback], so learners never see stack traces,
/// SQL or file paths. The original error is logged in debug builds.
String userMessage(Object? error, {required String fallback}) {
  if (error is AuthFailure) return error.message;
  if (error is OfflineStorageFailure) return error.message;
  appLog('LearnLite error (shown as "$fallback"): $error');
  return fallback;
}
