import 'package:flutter/material.dart';

import '../../app/app_colors.dart';
import '../../core/user_message.dart';
import '../auth/auth_gateway.dart';
import 'admin_content_screen.dart';
import 'admin_dictionary_screen.dart';
import 'admin_reports_screen.dart';

enum _AdminDestination { reports, upload, dictionary }

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({required this.gateway, super.key});

  final FirebaseAuthGateway gateway;

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthSession?>(
    stream: gateway.authStateChanges,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      if (!gateway.isConfigured || snapshot.data == null) {
        return _AdminLoginScreen(gateway: gateway);
      }
      return FutureBuilder<void>(
        future: gateway.verifyAdministrator(),
        builder: (context, verification) {
          if (verification.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          if (verification.hasError) {
            return _AdminAccessDenied(
              message: userMessage(
                verification.error,
                fallback: 'Administrator access could not be verified.',
              ),
              onSignOut: gateway.signOut,
            );
          }
          return _AdminShell(gateway: gateway);
        },
      );
    },
  );
}

class _AdminLoginScreen extends StatefulWidget {
  const _AdminLoginScreen({required this.gateway});

  final FirebaseAuthGateway gateway;

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      await widget.gateway.signIn(
        username: _usernameController.text,
        password: _passwordController.text,
      );
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBackground,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final form = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Administrator Login',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.darkBackground),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with an administrator account.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.gray),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your email.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        onFieldSubmitted: (_) => _signIn(),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                      if (!widget.gateway.isConfigured) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Administrator sign-in is unavailable until Firebase Authentication is configured.',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _isSigningIn || !widget.gateway.isConfigured
                            ? null
                            : _signIn,
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.gold,
                                  size: 56,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'LearnLite',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Learning content administration',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: AppColors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.all(28),
                            color: AppColors.cream,
                            child: form,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 36),
                          const Icon(
                            Icons.auto_stories_rounded,
                            color: AppColors.gold,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'LearnLite',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Card(
                            margin: const EdgeInsets.all(20),
                            color: AppColors.cream,
                            child: form,
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

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied({required this.message, required this.onSignOut});

  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Administrator access required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await onSignOut();
                  } on AuthFailure catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error.message)));
                    }
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AdminShell extends StatefulWidget {
  const _AdminShell({required this.gateway});

  final FirebaseAuthGateway gateway;

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  _AdminDestination _destination = _AdminDestination.reports;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      return Scaffold(
        appBar: AppBar(
          title: const Text('LearnLite Administration'),
          leading: desktop
              ? null
              : Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Open administration menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                  ),
                ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                try {
                  await widget.gateway.signOut();
                } on AuthFailure catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: desktop
            ? null
            : Drawer(
                child: _AdminMenu(
                  selected: _destination,
                  onSelected: (destination) {
                    setState(() => _destination = destination);
                    Navigator.of(context).pop();
                  },
                ),
              ),
        body: Row(
          children: [
            if (desktop)
              SizedBox(
                width: 210,
                child: _AdminMenu(
                  selected: _destination,
                  onSelected: (destination) =>
                      setState(() => _destination = destination),
                ),
              ),
            if (desktop) const VerticalDivider(width: 1),
            Expanded(child: _selectedPage()),
          ],
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                selectedIndex: _destination.index,
                onDestinationSelected: (index) => setState(
                  () => _destination = _AdminDestination.values[index],
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.analytics_outlined),
                    label: 'Reports',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.upload_file_outlined),
                    label: 'Content',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    label: 'Dictionary',
                  ),
                ],
              ),
      );
    },
  );

  Widget _selectedPage() => switch (_destination) {
    _AdminDestination.reports => AdminReportsScreen(gateway: widget.gateway),
    _AdminDestination.upload => AdminContentScreen(gateway: widget.gateway),
    _AdminDestination.dictionary => AdminDictionaryScreen(
      gateway: widget.gateway,
    ),
  };
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu({required this.selected, required this.onSelected});

  final _AdminDestination selected;
  final ValueChanged<_AdminDestination> onSelected;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 18),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Text(
          'CONTENT MANAGEMENT',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.gray),
        ),
      ),
      for (final item in _AdminDestination.values)
        ListTile(
          selected: selected == item,
          leading: Icon(switch (item) {
            _AdminDestination.reports => Icons.analytics_outlined,
            _AdminDestination.upload => Icons.upload_file_outlined,
            _AdminDestination.dictionary => Icons.menu_book_outlined,
          }),
          title: Text(switch (item) {
            _AdminDestination.reports => 'Reports',
            _AdminDestination.upload => 'Upload Content',
            _AdminDestination.dictionary => 'Dictionary',
          }),
          onTap: () => onSelected(item),
        ),
    ],
  );
}
