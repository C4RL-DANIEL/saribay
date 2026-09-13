import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../widgets/animated_widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _store = TextEditingController(text: 'My Sari-Sari Store');
  final _name = TextEditingController();
  final _user = TextEditingController(text: 'owner');
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await AuthService.instance.createOwner(
          _name.text.trim(), _user.text.trim(), _pin.text,
          storeName: _store.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Owner created! Please log in.'),
                backgroundColor: Color(0xFF1B8A5A)));
        // Force rebuild — go back to splash which will re-check setup
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const SizedBox(height: 20),
                const Hero(
                  tag: 'app_logo',
                  child: Icon(Icons.storefront, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set up your store and owner account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 32),

                // Form card
                AnimatedCard(
                  showShadow: true,
                  showShimmer: true,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Store name
                          TextFormField(
                            controller: _store,
                            decoration: InputDecoration(
                              labelText: 'Store Name',
                              prefixIcon: const Icon(Icons.store),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Owner name
                          TextFormField(
                            controller: _name,
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Username
                          TextFormField(
                            controller: _user,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.alternate_email),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          // PIN (4-6 digits)
                          TextFormField(
                            controller: _pin,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'PIN (4-6 digits)',
                              prefixIcon: const Icon(Icons.lock),
                              counterText: '',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 4) return 'Min 4 digits';
                              if (v.length > 6) return 'Max 6 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm PIN
                          TextFormField(
                            controller: _pin2,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Confirm PIN',
                              prefixIcon: const Icon(Icons.lock_outline),
                              counterText: '',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) =>
                                v != _pin.text ? 'PINs do not match' : null,
                          ),

                          // Error message
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

                          // Start button
                          AnimatedButton(
                            onPressed: _saving ? null : _create,
                            icon: Icons.rocket_launch,
                            isLoading: _saving,
                            child: const Text('Start'),
                          ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.rocket_launch, size: 20),
                                        SizedBox(width: 12),
                                        Text('Start',
                                            style: TextStyle(
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
    );
  }
}
