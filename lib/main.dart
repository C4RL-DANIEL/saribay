import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/db/database.dart';
import 'providers/cart_provider.dart';
import 'providers/session_provider.dart';
import 'services/settings_service.dart';
import 'ui/app_shell.dart';
import 'ui/screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database; // warm DB
  await SettingsService.instance.load();
  runApp(const SariBayApp());
}

class SariBayApp extends StatelessWidget {
  const SariBayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'SariBay POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return session.isLoggedIn ? const AppShell() : const LoginScreen();
  }
}
