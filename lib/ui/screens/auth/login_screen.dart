import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/session_provider.dart';
import '../../../services/auth_service.dart';
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
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    try {
      final v = await AuthService.instance.isSetupComplete();
      if (mounted) setState(() { _isSetup = v; _loading = false; });
    } catch (e) {
      // DB might not be ready — show setup screen as fallback
      if (mounted) setState(() { _isSetup = false; _loading = false; });
    }
  }

  Future<void> _login() async {
    setState(() { _error = null; });
    try {
      final user = await AuthService.instance
          .authenticate(_userCtrl.text.trim(), _pinCtrl.text);
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = 'Invalid username or PIN');
      } else {
        await context.read<SessionProvider>().login(user);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront, size: 80, color: Color(0xFF1B8A5A)),
              SizedBox(height: 24),
              CircularProgressIndicator(color: Color(0xFF1B8A5A)),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
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
                  const Icon(Icons.storefront,
                      size: 72, color: Color(0xFF1B8A5A)),
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
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
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
