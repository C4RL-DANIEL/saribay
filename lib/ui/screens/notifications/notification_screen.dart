import 'package:flutter/material.dart';

import '../../../data/db/database.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    _notifications = await db.query('notifications', orderBy: 'id DESC', limit: 100);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final db = await AppDatabase.instance.database;
              await db.rawUpdate("UPDATE notifications SET is_read = 1 WHERE is_read = 0");
              _load();
            },
            child: const Text('Read All'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (ctx, i) {
                    final n = _notifications[i];
                    final read = (n['is_read'] as int) == 1;
                    return ListTile(
                      leading: Icon(
                        _iconForType(n['type'] as String),
                        color: read ? Colors.grey : Colors.blue,
                      ),
                      title: Text(n['title'] as String,
                          style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text(n['message'] as String),
                      trailing: Text(n['created_at'] as String, style: const TextStyle(fontSize: 10)),
                      onTap: () async {
                        final db = await AppDatabase.instance.database;
                        await db.rawUpdate(
                            "UPDATE notifications SET is_read = 1 WHERE id = ?", [n['id']]);
                        _load();
                      },
                    );
                  },
                ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('stock')) return Icons.warning_amber;
    if (type.contains('credit')) return Icons.person_off;
    if (type.contains('sync')) return Icons.sync;
    if (type.contains('backup')) return Icons.backup;
    if (type.contains('anomaly')) return Icons.bug_report;
    return Icons.info;
  }
}
