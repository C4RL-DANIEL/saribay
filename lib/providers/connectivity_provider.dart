import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Detects online/offline status and notifies UI.
/// Online-only features are grayed out when offline.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityProvider() {
    _init();
  }

  void _init() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
    // Initial check
    Connectivity().checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Wrapper widget that disables children when offline.
class OnlineOnly extends StatelessWidget {
  final Widget child;
  final String offlineMessage;
  const OnlineOnly({super.key, required this.child, this.offlineMessage = 'Requires internet'});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().isOnline;
    if (online) return child;
    return Opacity(
      opacity: 0.4,
      child: Tooltip(
        message: offlineMessage,
        child: IgnorePointer(child: child),
      ),
    );
  }
}
