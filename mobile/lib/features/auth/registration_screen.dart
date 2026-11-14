import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/responsive_layout.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/learnlite_button.dart';
import '../../widgets/learnlite_brand_mark.dart';
import '../../widgets/learnlite_card.dart';
import '../../widgets/learnlite_text_field.dart';
import 'auth_gateway.dart';

enum LearningPreference { language, culture, both }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({this.authGateway, this.onLogin, super.key});

  final AuthGateway? authGateway;
  final VoidCallback? onLogin;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Timer? _availabilityTimer;
  LearningPreference? _preference;
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _usernameMessage;
  String? _errorMessage;

  AuthGateway get _gateway =>
      widget.authGateway ?? const UnavailableAuthGateway();

  @override
  void dispose() {
    _availabilityTimer?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _usernameChanged(String value) {
    _availabilityTimer?.cancel();
    setState(() {
      _checkingUsername = false;
      _usernameAvailable = null;
      _usernameMessage = null;
      _errorMessage = null;
    });
    final username = value.trim();
    if (!_validUsername(username)) return;
    _availabilityTimer = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(username),
    );
  }

  bool _validUsername(String value) =>
      RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(value);

  Future<void> _checkUsername(String username) async {
    if (!mounted || username != _usernameController.text.trim()) return;
    setState(() {
      _checkingUsername = true;
      _usernameMessage = null;
    });
    try {
      final available = await _gateway.isUsernameAvailable(username);
      if (!mounted || username != _usernameController.text.trim()) return;
      setState(() {
        _usernameAvailable = available;
        _usernameMessage = available
            ? 'Username is available on this device.'
            : 'That username is already used on this device.';
      });
    } on AuthFailure catch (error) {
      if (!mounted || username != _usernameController.text.trim()) return;
      setState(() {
        _usernameAvailable = null;
        _usernameMessage = error.message;
      });
    } finally {
      if (mounted && username == _usernameController.text.trim()) {
        setState(() => _checkingUsername = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preference == null) {
      setState(() => _errorMessage = 'Choose a learning preference.');
      return;
    }
    if (!_termsAccepted) {
      setState(
        () => _errorMessage = 'Accept the Terms and Conditions to continue.',
      );
      return;
    }

    _availabilityTimer?.cancel();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final username = _usernameController.text.trim();
      final available = await _gateway.isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _usernameAvailable = false;
          _usernameMessage = 'That username is already used on this device.';
          _errorMessage = 'Choose a different username.';
        });
        return;
      }
      setState(() {
        _usernameAvailable = true;
        _usernameMessage = 'Username is available on this device.';
      });
      await _gateway.register(
        fullName: _fullNameController.text.trim(),
        username: username,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        learningPreference: _preference!.name,
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
      appBar: AppBar(
        title: const Row(
          children: [
            LearnLiteBrandMark(size: 30),
            SizedBox(width: 8),
            Text('LearnLite'),
          ],
        ),
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: _returnToLogin,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = ResponsiveLayout.horizontalPadding(
              constraints.maxWidth,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set up your learner profile to get started.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.gray),
                      ),
                      const SizedBox(height: 18),
                      const _RegistrationStepIndicator(),
                      const SizedBox(height: 20),
                      LearnLiteCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LearnLiteTextField(
                                key: const ValueKey('registration-full-name'),
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                prefixIcon: Icons.person_outline,
                                textCapitalization: TextCapitalization.words,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter your full name.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              LearnLiteTextField(
                                key: const ValueKey('registration-email'),
                                controller: _emailController,
                                label: 'Email',
                                hint: 'Enter your email address',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 14),
                              LearnLiteTextField(
                                key: const ValueKey('registration-username'),
                                controller: _usernameController,
                                label: 'Username',
                                hint: 'Choose a username',
                                helperText: _usernameHelpText,
                                prefixIcon: Icons.alternate_email,
                                onChanged: _usernameChanged,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Choose a username.';
                                  }
                                  if (!_validUsername(value.trim())) {
                                    return 'Use 3–30 letters, numbers, or underscores.';
                                  }
                                  return null;
                                },
                                suffixIcon: _availabilityIcon,
                              ),
                              if (_usernameMessage != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  _usernameMessage!,
                                  style: TextStyle(
                                    color: _usernameAvailable == false
                                        ? AppColors.primary
                                        : _usernameAvailable == true
                                        ? const Color(0xFF3B7A57)
                                        : AppColors.gray,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              LearnLiteTextField(
                                key: const ValueKey('registration-password'),
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Create a password',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  key: const ValueKey(
                                    'toggle-registration-password-visibility',
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
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 14),
                              LearnLiteTextField(
                                key: const ValueKey(
                                  'registration-confirm-password',
                                ),
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: 'Re-enter your password',
                                prefixIcon: Icons.lock_reset_outlined,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  key: const ValueKey(
                                    'toggle-confirm-password-visibility',
                                  ),
                                  tooltip: _obscureConfirmPassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirm your password.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Learning preference',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final preference
                                      in LearningPreference.values)
                                    ChoiceChip(
                                      label: Text(_preferenceLabel(preference)),
                                      selected: _preference == preference,
                                      onSelected: _isSubmitting
                                          ? null
                                          : (_) => setState(() {
                                              _preference = preference;
                                              _errorMessage = null;
                                            }),
                                      selectedColor: AppColors.lightPink,
                                      side: BorderSide(
                                        color: _preference == preference
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                      labelStyle: TextStyle(
                                        color: _preference == preference
                                            ? AppColors.primary
                                            : AppColors.darkBackground,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _termsAccepted,
                                    onChanged: _isSubmitting
                                        ? null
                                        : (value) => setState(() {
                                            _termsAccepted = value ?? false;
                                            _errorMessage = null;
                                          }),
                                    activeColor: AppColors.primary,
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'I agree to the Terms and Conditions',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 8),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              LearnLiteButton(
                                label: 'Create Account',
                                icon: Icons.person_add_alt_1,
                                isLoading: _isSubmitting,
                                onPressed: _isSubmitting ? null : _submit,
                              ),
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : _returnToLogin,
                                child: const Text(
                                  'Already have an account? Login',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const DecorativeBorder(),
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

  String get _usernameHelpText {
    if (_checkingUsername) return 'Checking on-device username availability…';
    return '3–30 letters, numbers, or underscores. Sign in with your email.';
  }

  void _returnToLogin() {
    final onLogin = widget.onLogin;
    if (onLogin != null) {
      onLogin();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget? get _availabilityIcon {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameAvailable == null) return null;
    return Icon(
      _usernameAvailable! ? Icons.check_circle_outline : Icons.error_outline,
      color: _usernameAvailable! ? const Color(0xFF3B7A57) : AppColors.primary,
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Create a password.';
    if (value.length < 10 ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use 10+ characters with uppercase, lowercase, and a number.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String _preferenceLabel(LearningPreference preference) =>
      switch (preference) {
        LearningPreference.language => 'Language',
        LearningPreference.culture => 'Culture',
        LearningPreference.both => 'Both',
      };
}

class _RegistrationStepIndicator extends StatelessWidget {
  const _RegistrationStepIndicator();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Text(
            '1',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Account details',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Step 1 of 1',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.gray),
        ),
      ],
    );
  }
}
