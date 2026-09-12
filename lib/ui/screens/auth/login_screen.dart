import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../providers/session_provider.dart';
import '../../../services/auth_service.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _isSetup = false;
  String? _error;
  bool _logging = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _checkSetup();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSetup() async {
    try {
      final v = await AuthService.instance.isSetupComplete();
      if (mounted) setState(() { _isSetup = v; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _isSetup = false; _loading = false; });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _error = null; _logging = true; });
    try {
      final user = await AuthService.instance
          .authenticate(_userCtrl.text.trim(), _pinCtrl.text);
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = l.invalidCredentials);
      } else {
        await context.read<SessionProvider>().login(user);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${l.error}: $e');
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B8A5A), Color(0xFF0D5C3A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Brand
                  const Icon(Icons.storefront, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'SariBay POS',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sari-Sari Store Management',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 48),

                  // Login card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.login,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),

                            // Username
                            TextFormField(
                              controller: _userCtrl,
                              decoration: InputDecoration(
                                labelText: l.username,
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),

                            // PIN
                            TextFormField(
                              controller: _pinCtrl,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: l.pin,
                                prefixIcon: const Icon(Icons.lock),
                                counterText: '',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onFieldSubmitted: (_) => _login(),
                              validator: (v) =>
                                  v == null || v.length < 4 ? 'Min 4 digits' : null,
                            ),

                            // Error
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(_error!,
                                    style: const TextStyle(color: Colors.red)),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _logging ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B8A5A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                ),
                                child: _logging
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white))
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login, size: 20),
                                          const SizedBox(width: 12),
                                          Text(l.login,
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
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
}
