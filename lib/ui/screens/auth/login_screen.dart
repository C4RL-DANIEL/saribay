import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/session_provider.dart';
import '../../../../services/auth_service.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = true;
  bool _isSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthService.instance.isSetupComplete().then((v) {
      setState(() { _isSetup = v; _loading = false; });
    });
  }

  Future<void> _login() async {
    setState(() { _error = null; });
    final user = await AuthService.instance
        .authenticate(_userCtrl.text.trim(), _pinCtrl.text);
    if (!mounted) return;
    if (user == null) {
      setState(() => _error = 'Invalid username or PIN');
    } else {
      await context.read<SessionProvider>().login(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isSetup) return const SetupScreen();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.storefront,
                      size: 72, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('SariBay POS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Username', prefixIcon: Icon(Icons.person)),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(
                        labelText: 'PIN', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
