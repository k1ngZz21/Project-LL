import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import 'auth_gateway.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    required this.email,
    required this.authGateway,
    required this.onSignOut,
    required this.onVerified,
    super.key,
  });

  final String email;
  final AuthGateway authGateway;
  final Future<void> Function() onSignOut;
  final VoidCallback onVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;
  bool _isChecking = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _resend() async {
    setState(() {
      _isSending = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await widget.authGateway.resendVerificationEmail();
      if (mounted) {
        setState(() {
          _message = 'A new verification email has been sent.';
          _messageIsError = false;
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    try {
      final verified = await widget.authGateway.refreshEmailVerification();
      if (mounted) {
        setState(() {
          _message = verified ? 'Email verified. Opening your account…' : 'Your email is not verified yet. Open the link in your inbox, then try again.';
          _messageIsError = !verified;
        });
        if (verified) widget.onVerified();
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBackground,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 52,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 20),
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Verify ${widget.email} before continuing. Open the link in your inbox, or request a new verification email below.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.white),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _messageIsError
                            ? AppColors.gold
                            : AppColors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  child: _isChecking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("I've verified my email"),
                ),
                TextButton(
                  onPressed: _isSending ? null : _resend,
                  child: Text(
                    _isSending ? 'Sending…' : 'Resend verification email',
                  ),
                ),
                TextButton(
                  onPressed: widget.onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
