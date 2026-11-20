import 'package:flutter/foundation.dart';

/// Diagnostic logging for development builds only.
///
/// Flutter's `debugPrint` still writes to the device log in release builds,
/// where any app on a debuggable device or a connected PC could read it.
/// LearnLite's diagnostics can include exception text and server messages,
/// so release builds stay silent.
void appLog(String message) {
  if (!kReleaseMode) debugPrint(message);
}
