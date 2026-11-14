import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/firebase_options.dart';

void main() {
  test('uses the configured LearnLite Firebase project', () {
    expect(FirebaseOptionsConfig.expectedProjectId, 'learnlite-f1dd5');
    expect(FirebaseOptionsConfig.current.projectId, 'learnlite-f1dd5');
  });
}
