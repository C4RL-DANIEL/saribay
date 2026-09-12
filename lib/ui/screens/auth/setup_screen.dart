import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';

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

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    await AuthService.instance.createOwner(
        _name.text.trim(), _user.text.trim(), _pin.text, storeName: _store.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner created. Please log in.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Welcome! Set up your store and owner account.'),
              const SizedBox(height: 16),
              TextFormField(controller: _store,
                  decoration: const InputDecoration(labelText: 'Store name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _user,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _pin, obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN (min 4 digits)'),
                  validator: (v) => (v == null || v.length < 4) ? 'Min 4 digits' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _pin2, obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                  validator: (v) => v != _pin.text ? 'PINs do not match' : null),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _create,
                  icon: const Icon(Icons.rocket_launch), label: const Text('Start')),
            ],
          ),
        ),
      ),
    );
  }
}
