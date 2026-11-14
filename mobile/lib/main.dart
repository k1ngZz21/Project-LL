import 'package:flutter/material.dart';

import 'app/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authGateway = await FirebaseAuthGateway.initialize();
  runApp(LearnLiteApp(authGateway: authGateway));
}

class LearnLiteApp extends StatelessWidget {
  const LearnLiteApp({required this.authGateway, super.key});

  final AuthGateway authGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LearnLite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(gateway: authGateway),
    );
  }
}
