import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_brand_mark.dart';
import '../../widgets/learnlite_text_field.dart';
import 'auth_gateway.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.authGateway,
    this.onCreateAccount,
    this.onContinueOffline,
    this.initialErrorMessage,
    super.key,
  });

  final AuthGateway? authGateway;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onContinueOffline;
  final String? initialErrorMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  AuthGateway get _gateway =>
      widget.authGateway ?? const UnavailableAuthGateway();

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialErrorMessage != oldWidget.initialErrorMessage) {
      _errorMessage = widget.initialErrorMessage;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _gateway.signIn(
        username: _usernameController.text,
        password: _passwordController.text,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      Container(
                        color: AppColors.cream,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Log in to continue learning.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.gray),
                              ),
                              const SizedBox(height: 20),
                              LearnLiteTextField(
                                key: const ValueKey('login-username'),
                                controller: _usernameController,
                                label: 'Email',
                                hint: 'Enter your email address',
                                textCapitalization: TextCapitalization.none,
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                                validator: _validateIdentifier,
                              ),
                              const SizedBox(height: 14),
                              LearnLiteTextField(
                                key: const ValueKey('login-password'),
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••',
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  key: const ValueKey(
                                    'toggle-login-password-visibility',
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter your password.'
                                    : null,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showPasswordRecovery,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              if (_errorMessage != null)
                                _ErrorMessage(message: _errorMessage!),
                              const SizedBox(height: 4),
                              LearnLiteButton(
                                label: 'Log in',
                                isLoading: _isSubmitting,
                                onPressed: _isSubmitting ? null : _submit,
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'or',
                                      style: TextStyle(color: AppColors.gray),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LearnLiteButton(
                                label: 'Create an account',
                                onPressed: _isSubmitting
                                    ? null
                                    : widget.onCreateAccount ??
                                          () => Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  RegistrationScreen(
                                                    authGateway:
                                                        widget.authGateway,
                                                  ),
                                            ),
                                          ),
                                variant: LearnLiteButtonVariant.outlined,
                              ),
                              if (widget.onContinueOffline != null) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  key: const ValueKey('continue-offline'),
                                  onPressed: widget.onContinueOffline,
                                  icon: const Icon(
                                    Icons.download_for_offline_outlined,
                                  ),
                                  label: const Text(
                                    'Continue with downloaded lessons',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.offline_pin_outlined,
                                    size: 17,
                                    color: AppColors.gray,
                                  ),
                                  SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Downloaded learning works offline; sign-in needs Internet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.gray,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_gateway.isConfigured) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Sign-in is not configured yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.gray,
                                    fontSize: 12,
                                  ),
                                ),
                                if (_gateway.initializationError != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _gateway.initializationError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.gray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPasswordRecovery() {
    return showDialog<void>(
      context: context,
      builder: (context) => _PasswordResetDialog(authGateway: _gateway),
    );
  }

  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.authGateway});

  final AuthGateway authGateway;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _messageIsError = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _message = 'Enter a valid email address.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await widget.authGateway.sendPasswordResetEmail(email);
      if (mounted) {
        setState(() {
          _message = 'If an account matches that email, a password reset link is on its way.';
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset your password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enter the email address linked to your account.'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('password-reset-email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'name@example.com',
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? AppColors.primary : AppColors.gray,
              ),
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _isSending ? null : () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _isSending ? null : _sendResetEmail,
        child: _isSending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send reset email'),
      ),
    ],
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground,
      child: Column(
        children: [
          const DecorativeBorder(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
            child: Column(
              children: [
                const LearnLiteBrandMark(size: 68),
                const SizedBox(height: 12),
                Text(
                  'LearnLite',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    'Learn the Subanen language and culture, even without internet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFD8D0C4),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const DecorativeBorder(),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(message, style: const TextStyle(color: AppColors.primary)),
      ),
    );
  }
}
