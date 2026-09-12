import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../data/models/models.dart';
import '../../../providers/session_provider.dart';
import 'package:provider/provider.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});
  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _users = await AuthService.instance.listUsers();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: session.can(Perms.manageUsers)
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(),
              child: const Icon(Icons.person_add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No employees'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(u.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(u.name),
                      subtitle: Text('${u.role} · @${u.username}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => _handleMenu(v, u),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'pin', child: Text('Reset PIN')),
                          const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _handleMenu(String action, AppUser user) async {
    if (action == 'deactivate') {
      await AuthService.instance.deactivateUser(user.id!);
      _load();
    } else if (action == 'pin') {
      final ctrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reset PIN for ${user.name}'),
          content: TextField(controller: ctrl, obscureText: true, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New PIN')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () async {
              if (ctrl.text.length >= 4) {
                await AuthService.instance.resetPin(user.id!, ctrl.text);
                Navigator.pop(ctx);
              }
            }, child: const Text('Save')),
          ],
        ),
      );
    }
  }

  void _showAddDialog() {
    final name = TextEditingController();
    final user = TextEditingController();
    final pin = TextEditingController();
    String role = 'CASHIER';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(controller: user, decoration: const InputDecoration(labelText: 'Username *')),
              const SizedBox(height: 8),
              TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PIN *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                items: ['CASHIER', 'MANAGER', 'STOCK_CLERK'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => role = v ?? role,
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || user.text.trim().isEmpty || pin.text.length < 4) return;
              await AuthService.instance.addUser(name.text.trim(), user.text.trim(), pin.text, role);
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
