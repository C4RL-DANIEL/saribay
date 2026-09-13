import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../providers/session_provider.dart';
import '../../../services/auth_service.dart';
import '../../widgets/animated_widgets.dart';
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
  bool _biometricsAvailable = false;
  bool _showBiometricButton = false;
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
    _checkBiometrics();
    _checkSavedCredentials();
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

  Future<void> _checkBiometrics() async {
    try {
      final localAuth = LocalAuthentication();
      final canAuth = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      setState(() => _biometricsAvailable = canAuth && isSupported);
    } catch (e) {
      setState(() => _biometricsAvailable = false);
    }
  }

  Future<void> _checkSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLogin = prefs.getBool('auto_login_enabled') ?? false;
    final savedUsername = prefs.getString('saved_username');
    if (autoLogin && savedUsername != null) {
      setState(() {
        _userCtrl.text = savedUsername;
        _showBiometricButton = true;
      });
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
        setState(() => _error = AppLocalizations.of(context).invalidCredentials);
      } else {
        // Save PIN hash for auto-login if enabled
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('auto_login_enabled') ?? false) {
          await prefs.setString('saved_pin_hash', _pinCtrl.text);
          await prefs.setString('saved_username', _userCtrl.text.trim());
        }
        await context.read<SessionProvider>().login(user);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${AppLocalizations.of(context).error}: $e');
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final localAuth = LocalAuthentication();
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Login with biometrics',
        options: const AuthenticationOptions(),
      );
      if (didAuth && mounted) {
        // Try auto-login with saved credentials
        final prefs = await SharedPreferences.getInstance();
        final savedUsername = prefs.getString('saved_username');
        final savedPin = prefs.getString('saved_pin_hash');
        if (savedUsername != null && savedPin != null) {
          setState(() { _error = null; _logging = true; });
          final user = await AuthService.instance.authenticate(savedUsername, savedPin);
          if (mounted) {
            if (user != null) {
              await context.read<SessionProvider>().login(user);
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              setState(() => _error = 'Saved credentials expired. Please login manually.');
            }
          }
        } else {
          if (mounted) {
            setState(() => _error = 'No saved credentials. Please login manually first.');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Biometric authentication failed');
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
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Brand with Hero animation
                  const Hero(
                    tag: 'app_logo',
                    child: Icon(Icons.storefront, size: 80, color: Colors.white),
                  ),
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
                  AnimatedCard(
                    showShadow: true,
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
                            AnimatedButton(
                              onPressed: _logging ? null : _login,
                              icon: Icons.login,
                              isLoading: _logging,
                              child: Text(l.login),
                            ),

                            // Biometric login button
                            if (_biometricsAvailable && _showBiometricButton) ...[
                              const SizedBox(height: 16),
                              AnimatedButton(
                                onPressed: _biometricLogin,
                                icon: Icons.fingerprint,
                                color: Colors.blue,
                                child: const Text('Login with Biometrics'),
                              ),
                            ],
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
