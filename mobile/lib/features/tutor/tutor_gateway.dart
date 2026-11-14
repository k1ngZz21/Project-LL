import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

abstract interface class TutorTokenProvider {
  Future<String?> tutorIdToken();
}

enum TutorMessageRole { user, assistant }

class TutorMessage {
  const TutorMessage({required this.role, required this.content});

  final TutorMessageRole role;
  final String content;

  Map<String, String> toJson() => {'role': role.name, 'content': content};
}

class TutorReply {
  const TutorReply({required this.content, this.model});

  final String content;
  final String? model;
}

class TutorFailure implements Exception {
  const TutorFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class OllamaTutorGateway {
  OllamaTutorGateway({
    required this.idTokenProvider,
    String? apiBaseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 100),
  }) : _apiBaseUrl =
           (apiBaseUrl ??
                   const String.fromEnvironment('LEARNLITE_API_BASE_URL'))
               .trim(),
       _client = client ?? http.Client();

  final Future<String?> Function() idTokenProvider;
  final String _apiBaseUrl;
  final http.Client _client;
  final Duration timeout;

  String? get configurationMessage {
    if (_apiBaseUrl.isEmpty) {
      return 'The Tutor API address is not configured. Set '
          'LEARNLITE_API_BASE_URL to the existing LearnLite API address.';
    }
    final uri = Uri.tryParse(_apiBaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'The Tutor API address is invalid. Check '
          'LEARNLITE_API_BASE_URL and try again.';
    }
    if (kReleaseMode && uri.scheme != 'https') {
      return 'The Tutor API must use HTTPS in release builds.';
    }
    return null;
  }

  Future<TutorReply> sendMessages(List<TutorMessage> messages) async {
    final configurationError = configurationMessage;
    if (configurationError != null) {
      throw TutorFailure(configurationError);
    }
    if (messages.isEmpty || messages.length > 10) {
      throw const TutorFailure('A chat request must contain 1 to 10 messages.');
    }
    for (final message in messages) {
      final content = message.content.trim();
      if (content.isEmpty || content.length > 4000) {
        throw const TutorFailure(
          'Each message must contain 1 to 4,000 characters.',
        );
      }
    }
    if (messages.last.role != TutorMessageRole.user) {
      throw const TutorFailure('Send a learner message to continue.');
    }

    final token = await idTokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const TutorFailure(
        'Sign in with a verified LearnLite account to use the AI Tutor.',
      );
    }

    final baseUri = Uri.parse(_apiBaseUrl);
    final path = baseUri.path.endsWith('/')
        ? '${baseUri.path}ai/chat'
        : '${baseUri.path}/ai/chat';
    final endpoint = baseUri.replace(path: path);
    late final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': messages.map((message) => message.toJson()).toList(),
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TutorFailure(
        'The Tutor service timed out. Check that the local Ollama model is running and try again.',
      );
    } on http.ClientException {
      throw const TutorFailure(
        'The Tutor service is unavailable. Check your connection and that the existing LearnLite API is running.',
      );
    }

    late final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Expected an object response.');
      }
      body = Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const TutorFailure(
        'The Tutor service returned an invalid response.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body['detail'];
      throw TutorFailure(
        detail is String && detail.trim().isNotEmpty
            ? detail
            : 'The Tutor request failed (HTTP ${response.statusCode}).',
      );
    }

    final content = body['response'];
    if (content is! String || content.trim().isEmpty) {
      throw const TutorFailure(
        'The Tutor service returned an empty response. Try again.',
      );
    }
    final model = body['model'];
    return TutorReply(
      content: content.trim(),
      model: model is String && model.trim().isNotEmpty ? model.trim() : null,
    );
  }

  void close() => _client.close();
}
