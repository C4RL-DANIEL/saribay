import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/db/database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _backups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance.database;
    _backups = await db.query('backups', orderBy: 'id DESC');
    setState(() => _loading = false);
  }

  Future<void> _backup() async {
    try {
      final db = await AppDatabase.instance.database;
      final docs = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupPath = '${docs.path}/saribay_backup_$timestamp.db';
      // Copy database
      await db.execute("VACUUM INTO '$backupPath'");
      final file = File(backupPath);
      final size = await file.length();
      await db.insert('backups', {
        'type': 'MANUAL',
        'file_path': backupPath,
        'size_bytes': size,
        'status': 'SUCCESS',
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup created (${(size / 1024).toStringAsFixed(0)} KB)')),
        );
      }
    } catch (e) {
      final db = await AppDatabase.instance.database;
      await db.insert('backups', {
        'type': 'MANUAL', 'status': 'FAILED', 'error': e.toString(),
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _backup,
        icon: const Icon(Icons.backup),
        label: const Text('Backup Now'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _backups.length,
              itemBuilder: (ctx, i) {
                final b = _backups[i];
                final success = b['status'] == 'SUCCESS';
                final size = (b['size_bytes'] as int?) ?? 0;
                return ListTile(
                  leading: Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: success ? Colors.green : Colors.red,
                  ),
                  title: Text('${b['type']} Backup'),
                  subtitle: Text('${b['created_at']}\n${size > 0 ? "${(size / 1024).toStringAsFixed(0)} KB" : b['error'] ?? ""}'),
                  trailing: success && b['file_path'] != null
                      ? IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            Share.shareXFiles([XFile(b['file_path'] as String)]);
                          },
                        )
                      : null,
                );
              },
            ),
    );
  }
}
