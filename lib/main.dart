import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/db/database.dart';
import 'providers/cart_provider.dart';
import 'providers/session_provider.dart';
import 'services/settings_service.dart';
import 'ui/screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error handling — prevent black screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: ${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  };

  try {
    await AppDatabase.instance.database;
    await SettingsService.instance.load();
  } catch (e) {
    debugPrint('Startup error: $e');
  }

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
        home: const LoginScreen(),
      ),
    );
  }
}
