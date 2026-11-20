import 'package:flutter_test/flutter_test.dart';
import 'package:learnlite/features/auth/auth_gateway.dart';
import 'package:learnlite/firebase_options.dart';

void main() {
  test('uses the configured LearnLite Firebase project', () {
    expect(FirebaseOptionsConfig.expectedProjectId, 'learnlite-f1dd5');
    expect(FirebaseOptionsConfig.current.projectId, 'learnlite-f1dd5');
  });

  test('connection failures reported as unknown are treated as offline', () {
    String code(String c, String? m) =>
        FirebaseAuthGateway.normalizedAuthErrorCode(c, m);
    expect(code('unknown', 'A network error (such as timeout) occurred'),
        'network-request-failed');
    expect(code('unknown', 'Failed to connect to /10.0.2.2:9'),
        'network-request-failed');
    expect(code('internal-error', 'Unable to resolve host "x"'),
        'network-request-failed');
    expect(code('unknown', 'Something else'), 'unknown');
    expect(code('unknown', null), 'unknown');
    expect(code('wrong-password', 'network'), 'wrong-password',
        reason: 'only vague codes are reinterpreted');
  });

  group('Auth emulator address', () {
    test('is unset in normal builds', () {
      expect(FirebaseAuthGateway.authEmulatorAddress, isEmpty);
    });

    test('parses host and port in debug builds', () {
      final address = FirebaseAuthGateway.parseEmulatorAddress(
        '10.0.2.2:9099',
        releaseMode: false,
      );
      expect(address?.host, '10.0.2.2');
      expect(address?.port, 9099);
    });

    test('is ignored in release builds and when malformed', () {
      expect(
        FirebaseAuthGateway.parseEmulatorAddress(
          '10.0.2.2:9099',
          releaseMode: true,
        ),
        isNull,
      );
      for (final value in ['', '10.0.2.2', ':9099', '10.0.2.2:x', 'h:70000']) {
        expect(
          FirebaseAuthGateway.parseEmulatorAddress(value, releaseMode: false),
          isNull,
          reason: value,
        );
      }
    });
  });
}
