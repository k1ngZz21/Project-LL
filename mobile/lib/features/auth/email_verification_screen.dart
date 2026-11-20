import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_theme.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/learnlite_brand_mark.dart';
import '../../widgets/learnlite_button.dart';
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LearnLiteBrandMark(size: 56),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: ColoredBox(
                    color: AppColors.cream,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DecorativeBorder(height: 10),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                          child: Column(
                            children: [
                              const IconBadge(
                                icon: Icons.mark_email_unread_rounded,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Verify your email',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Verify ${widget.email} before continuing. Open the link in your inbox, or request a new verification email below.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _messageIsError
                                          ? AppColors.lightPink
                                          : AppColors.successSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _message!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _messageIsError
                                            ? AppColors.redDark
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              LearnLiteButton(
                                onPressed: _isChecking
                                    ? null
                                    : _checkVerification,
                                isLoading: _isChecking,
                                icon: Icons.verified_rounded,
                                label: "I've verified my email",
                              ),
                              const SizedBox(height: 10),
                              LearnLiteButton(
                                variant: LearnLiteButtonVariant.outlined,
                                onPressed: _isSending ? null : _resend,
                                icon: Icons.forward_to_inbox_rounded,
                                label: _isSending
                                    ? 'Sending…'
                                    : 'Resend verification email',
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: widget.onSignOut,
                                child: const Text('Sign out'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
