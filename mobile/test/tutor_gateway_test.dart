import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnlite/features/tutor/tutor_gateway.dart';

void main() {
  test('sends authenticated chat to the existing LearnLite API', () async {
    var tokenRequested = false;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.parse('http://127.0.0.1:8000/ai/chat'));
      expect(request.headers['Authorization'], 'Bearer verified-token');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['messages'], [
        {'role': 'user', 'content': 'Help me study.'},
      ]);
      return http.Response(
        jsonEncode({'response': 'Review one lesson at a time.', 'model': 'local'}),
        200,
      );
    });
    final gateway = OllamaTutorGateway(
      apiBaseUrl: 'http://127.0.0.1:8000',
      idTokenProvider: () async {
        tokenRequested = true;
        return 'verified-token';
      },
      client: client,
    );
    addTearDown(gateway.close);

    final reply = await gateway.sendMessages(const [
      TutorMessage(role: TutorMessageRole.user, content: 'Help me study.'),
    ]);

    expect(tokenRequested, isTrue);
    expect(reply.content, 'Review one lesson at a time.');
    expect(reply.model, 'local');
  });

  test('rejects missing API configuration before requesting a token', () async {
    var tokenRequested = false;
    final gateway = OllamaTutorGateway(
      apiBaseUrl: '',
      idTokenProvider: () async {
        tokenRequested = true;
        return 'verified-token';
      },
    );
    addTearDown(gateway.close);

    await expectLater(
      gateway.sendMessages(const [
        TutorMessage(role: TutorMessageRole.user, content: 'Hello'),
      ]),
      throwsA(isA<TutorFailure>()),
    );
    expect(tokenRequested, isFalse);
    expect(gateway.configurationMessage, contains('not configured'));
  });

  group('release builds (F13)', () {
    OllamaTutorGateway gatewayFor(String url, {bool allowLanHttp = false}) {
      final gateway = OllamaTutorGateway(
        apiBaseUrl: url,
        idTokenProvider: () async => 'verified-token',
        releaseMode: true,
        allowLanHttp: allowLanHttp,
      );
      addTearDown(gateway.close);
      return gateway;
    }

    test('require HTTPS by default', () {
      expect(gatewayFor('https://tutor.example.org').configurationMessage,
          isNull);
      expect(gatewayFor('http://192.168.1.10:8000').configurationMessage,
          contains('HTTPS'));
    });

    test('allow HTTP to a private address only when opted in', () {
      for (final url in [
        'http://192.168.1.10:8000',
        'http://10.0.2.2:8000',
        'http://172.20.0.5:8000',
      ]) {
        expect(gatewayFor(url, allowLanHttp: true).configurationMessage,
            isNull, reason: url);
      }
      for (final url in [
        'http://tutor.example.org',
        'http://8.8.8.8:8000',
        'http://172.32.0.1:8000',
        'http://192.168.1.10.example.org',
        'http://localhost:8000',
      ]) {
        expect(gatewayFor(url, allowLanHttp: true).configurationMessage,
            contains('HTTPS'), reason: url);
      }
    });

    test('private address check rejects malformed hosts', () {
      expect(OllamaTutorGateway.isPrivateNetworkAddress('192.168.001.1'),
          isFalse);
      expect(OllamaTutorGateway.isPrivateNetworkAddress('10.0.0'), isFalse);
      expect(OllamaTutorGateway.isPrivateNetworkAddress('10.0.0.256'), isFalse);
      expect(OllamaTutorGateway.isPrivateNetworkAddress('10.1.2.3'), isTrue);
    });
  });

  test('surfaces the existing API error detail without a fake reply', () async {
    final gateway = OllamaTutorGateway(
      apiBaseUrl: 'http://127.0.0.1:8000',
      idTokenProvider: () async => 'verified-token',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'detail': 'Ollama is offline'}), 503),
      ),
    );
    addTearDown(gateway.close);

    await expectLater(
      gateway.sendMessages(const [
        TutorMessage(role: TutorMessageRole.user, content: 'Hello'),
      ]),
      throwsA(
        isA<TutorFailure>().having(
          (failure) => failure.message,
          'message',
          'Ollama is offline',
        ),
      ),
    );
  });
}
