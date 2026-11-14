import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../app/app_navigation.dart';
import '../../widgets/decorative_border.dart';
import '../../widgets/learnlite_brand_mark.dart';
import 'auth_gateway.dart';
import 'avatar_creation_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({required this.gateway, super.key});

  final AuthGateway gateway;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegistration = false;
  bool _showOfflineLearning = false;
  String? _profileUid;
  String? _verifiedUid;
  Future<LearnerProfile>? _profileFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: widget.gateway.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LearnLiteSplash();
        }
        if (snapshot.hasError) {
          return LoginScreen(
            authGateway: widget.gateway,
            initialErrorMessage:
                'Could not read your sign-in state. Please try again.',
          );
        }
        if (snapshot.data == null) {
          _profileUid = null;
          _verifiedUid = null;
          _profileFuture = null;
          if (_showOfflineLearning) {
            return AppShell(
              profile: const LearnerProfile(username: '', fullName: ''),
              authGateway: widget.gateway,
              isGuest: true,
              onSignIn: () => setState(() => _showOfflineLearning = false),
            );
          }
        }
        if (snapshot.data != null) {
          final session = snapshot.data!;
          if (session.email != null &&
              !session.emailVerified &&
              _verifiedUid != session.uid) {
            return EmailVerificationScreen(
              email: session.email!,
              authGateway: widget.gateway,
              onSignOut: _signOut,
              onVerified: () {
                if (!mounted) return;
                setState(() {
                  _verifiedUid = session.uid;
                  _profileUid = session.uid;
                  _profileFuture = widget.gateway.fetchProfile();
                });
              },
            );
          }
          if (_profileUid != session.uid) {
            _profileUid = session.uid;
            _profileFuture = widget.gateway.fetchProfile();
          }
          return FutureBuilder<LearnerProfile>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const _LearnLiteSplash();
              }
              if (profileSnapshot.hasError || !profileSnapshot.hasData) {
                return _ProfileLoadFailure(
                  message: profileSnapshot.error is AuthFailure
                      ? (profileSnapshot.error as AuthFailure).message
                      : 'Could not load your learner profile.',
                  onRetry: () {
                    setState(() {
                      _profileFuture = widget.gateway.fetchProfile();
                    });
                  },
                  onSignOut: _signOut,
                );
              }
              final profile = profileSnapshot.data!;
              if (!profile.avatarCompleted) {
                return AvatarCreationScreen(
                  profile: profile,
                  authGateway: widget.gateway,
                  onSaved: (updated) => setState(() {
                    _profileFuture = Future.value(updated);
                  }),
                  onSignOut: _signOut,
                );
              }
              return AppShell(
                profile: profile,
                authGateway: widget.gateway,
                onProfileUpdated: (updated) => setState(() {
                  _profileFuture = Future.value(updated);
                }),
                onSignOut: _signOut,
              );
            },
          );
        }
        if (_showRegistration) {
          return RegistrationScreen(
            authGateway: widget.gateway,
            onLogin: () => setState(() => _showRegistration = false),
          );
        }
        return LoginScreen(
          authGateway: widget.gateway,
          onCreateAccount: () => setState(() => _showRegistration = true),
          onContinueOffline: () => setState(() => _showOfflineLearning = true),
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.gateway.signOut();
      if (mounted) {
        setState(() {
          _showRegistration = false;
          _showOfflineLearning = false;
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _LearnLiteSplash extends StatelessWidget {
  const _LearnLiteSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DecorativeBorder(height: 12),
                const SizedBox(height: 32),
                const LearnLiteBrandMark(size: 76),
                const SizedBox(height: 16),
                Text(
                  'LearnLite',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Preparing your learning space…'),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 32),
                const DecorativeBorder(height: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileLoadFailure extends StatelessWidget {
  const _ProfileLoadFailure({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 16),
            const Text(
              'Your profile could not be loaded.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
