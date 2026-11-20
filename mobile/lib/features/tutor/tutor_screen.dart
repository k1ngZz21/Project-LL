import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_theme.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_text_field.dart';
import '../auth/auth_models.dart';
import 'tutor_gateway.dart';

class TutorScreen extends StatefulWidget {
  const TutorScreen({
    required this.isGuest,
    this.idTokenProvider,
    this.onSignIn,
    this.apiBaseUrl,
    super.key,
  });

  final bool isGuest;
  final Future<String?> Function()? idTokenProvider;
  final VoidCallback? onSignIn;
  final String? apiBaseUrl;

  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final OllamaTutorGateway _gateway;
  final List<TutorMessage> _conversation = [];
  final List<_DisplayedMessage> _displayedMessages = [];
  bool _isSending = false;
  String? _errorMessage;
  String? _failedPrompt;
  String? _modelName;

  @override
  void initState() {
    super.initState();
    _gateway = OllamaTutorGateway(
      idTokenProvider: widget.idTokenProvider ?? () async => null,
      apiBaseUrl: widget.apiBaseUrl,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _gateway.close();
    super.dispose();
  }

  Future<void> _send() async {
    final prompt = _inputController.text.trim();
    if (prompt.isEmpty ||
        _isSending ||
        widget.isGuest ||
        _gateway.configurationMessage != null) {
      return;
    }
    _inputController.clear();
    await _sendPrompt(prompt, addVisibleMessage: true);
  }

  Future<void> _retry() async {
    final prompt = _failedPrompt;
    if (prompt == null || _isSending) return;
    await _sendPrompt(prompt, addVisibleMessage: false);
  }

  Future<void> _sendPrompt(
    String prompt, {
    required bool addVisibleMessage,
  }) async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _failedPrompt = null;
      if (addVisibleMessage) {
        _displayedMessages.add(
          _DisplayedMessage(role: TutorMessageRole.user, content: prompt),
        );
      }
    });
    _scrollToEnd();

    final history = _conversation.length > 9
        ? _conversation.skip(_conversation.length - 9).toList()
        : List<TutorMessage>.of(_conversation);
    final requestMessages = [
      ...history,
      TutorMessage(role: TutorMessageRole.user, content: prompt),
    ];

    try {
      final reply = await _gateway.sendMessages(requestMessages);
      if (!mounted) return;
      setState(() {
        _conversation
          ..clear()
          ..addAll(requestMessages)
          ..add(
            TutorMessage(
              role: TutorMessageRole.assistant,
              content: reply.content,
            ),
          );
        _displayedMessages.add(
          _DisplayedMessage(
            role: TutorMessageRole.assistant,
            content: reply.content,
          ),
        );
        _modelName = reply.model;
      });
    } on TutorFailure catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _failedPrompt = prompt;
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _failedPrompt = prompt;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToEnd();
      }
    }
  }

  void _clearConversation() {
    setState(() {
      _conversation.clear();
      _displayedMessages.clear();
      _errorMessage = null;
      _failedPrompt = null;
      _modelName = null;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Tutor'),
          if (_modelName case final model?)
            Text(
              model,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.gray),
            ),
        ],
      ),
      actions: [
        if (_displayedMessages.isNotEmpty)
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _isSending ? null : _clearConversation,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
      ],
      bottom: weaveAppBarBottom,
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_gateway.configurationMessage case final message?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ServiceNotice(message: message),
            ),
          Expanded(
            child: _displayedMessages.isEmpty
                ? _buildWelcome()
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    children: [
                      for (final message in _displayedMessages)
                        _MessageBubble(message: message),
                      if (_isSending)
                        const _ThinkingIndicator()
                      else if (_errorMessage != null)
                        _RequestFailure(
                          message: _errorMessage!,
                          canRetry: _failedPrompt != null,
                          onRetry: _retry,
                        ),
                    ],
                  ),
          ),
          _buildComposer(context),
        ],
      ),
    ),
  );

  Widget _buildWelcome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(
              icon: Icons.auto_awesome_rounded,
              tone: IconBadgeTone.dark,
              size: 72,
            ),
            const SizedBox(height: 18),
            Text(
              'Learn with the AI Tutor',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Ask for help understanding a lesson or planning how to study. '
              'The tutor runs on LearnLite\'s own local AI and never invents '
              'Subanen words or dictionary entries.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.isGuest) ...[
              const SizedBox(height: 18),
              const Text(
                'Sign in with a verified LearnLite account to use the AI Tutor.',
                textAlign: TextAlign.center,
              ),
              if (widget.onSignIn != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onSignIn,
                  child: const Text('Sign in'),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildComposer(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: AppColors.white,
      elevation: 6,
      shadowColor: AppColors.shadow.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LearnLiteTextField(
                key: const ValueKey('tutor-message-input'),
                controller: _inputController,
                label: 'Ask a question',
                hint: widget.isGuest
                    ? 'Sign in to use the AI Tutor'
                    : 'Type your question',
                enabled: !widget.isGuest && !_isSending,
                maxLines: 3,
                maxLength: 4000,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('tutor-send'),
              tooltip: 'Send question',
              // Disabled while the Tutor is unavailable, so the button never
              // looks usable when it cannot work.
              onPressed:
                  widget.isGuest ||
                      _isSending ||
                      _gateway.configurationMessage != null
                  ? null
                  : _send,
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DisplayedMessage {
  const _DisplayedMessage({required this.role, required this.content});

  final TutorMessageRole role;
  final String content;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _DisplayedMessage message;

  @override
  Widget build(BuildContext context) {
    final isLearner = message.role == TutorMessageRole.user;
    return Align(
      alignment: isLearner ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLearner ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isLearner ? 20 : 6),
              bottomRight: Radius.circular(isLearner ? 6 : 20),
            ),
            border: isLearner ? null : Border.all(color: AppColors.borderSoft),
            boxShadow: AppShadows.card,
          ),
          child: SelectableText(
            message.content,
            style: TextStyle(
              color: isLearner ? AppColors.white : AppColors.darkBackground,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceNotice extends StatelessWidget {
  const _ServiceNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => LearnLiteCard(
    backgroundColor: AppColors.lightPink,
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 10),
          Text('Waiting for the local Tutor service…'),
        ],
      ),
    ),
  );
}

class _RequestFailure extends StatelessWidget {
  const _RequestFailure({
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LearnLiteCard(
      backgroundColor: AppColors.lightPink,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          if (canRetry) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('tutor-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    ),
  );
}
