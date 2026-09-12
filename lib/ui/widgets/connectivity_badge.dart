import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connectivity_provider.dart';

/// Shows online/offline status badge.
class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: isOnline ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isOnline ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a button to disable it when offline.
class OnlineOnlyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  const OnlineOnlyButton({super.key, required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    if (isOnline) return child;
    return Opacity(
      opacity: 0.5,
      child: Tooltip(
        message: 'Requires internet connection',
        child: IgnorePointer(child: child),
      ),
    );
  }
}
