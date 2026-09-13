import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles auto-login with biometrics and session management.
class SecurityService extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  Timer? _logoutTimer;
  Timer? _warningTimer;
  bool _isLocked = false;
  bool get isLocked => _isLocked;
  
  int _sessionTimeoutMinutes = 30;
  bool _biometricsEnabled = false;
  bool get biometricsEnabled => _biometricsEnabled;
  
  DateTime? _lastActivityTime;
  DateTime? get lastActivityTime => _lastActivityTime;
  
  static const _keyAutoLogin = 'auto_login_enabled';
  static const _keySessionTimeout = 'session_timeout';
  static const _keyBiometrics = 'biometrics_enabled';
  static const _keyLastActivity = 'last_activity';
  static const _keyPinHash = 'saved_pin_hash';

  SecurityService() {
    _loadSettings();
    _resetActivityTimer();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricsEnabled = prefs.getBool(_keyBiometrics) ?? false;
    _sessionTimeoutMinutes = prefs.getInt(_keySessionTimeout) ?? 30;
    notifyListeners();
  }

  /// Check if biometrics are available and enabled
  Future<bool> canUseBiometrics() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with biometrics
  Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(),
      );
      if (didAuth) {
        _resetActivityTimer();
      }
      return didAuth;
    } catch (e) {
      return false;
    }
  }

  /// Enable/disable biometrics
  Future<void> setBiometrics(bool enabled) async {
    _biometricsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometrics, enabled);
    notifyListeners();
  }

  /// Set session timeout
  Future<void> setSessionTimeout(int minutes) async {
    _sessionTimeoutMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySessionTimeout, minutes);
    _resetActivityTimer();
    notifyListeners();
  }

  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;

  /// Record user activity to reset timeout
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _resetActivityTimer();
  }

  /// Reset the logout timer
  void _resetActivityTimer() {
    _logoutTimer?.cancel();
    _warningTimer?.cancel();
    
    if (_sessionTimeoutMinutes <= 0) return;
    
    // Warning 2 minutes before logout
    final warningTime = Duration(minutes: _sessionTimeoutMinutes - 2);
    if (warningTime.isNegative == false) {
      _warningTimer = Timer(warningTime, () {
        _isLocked = true;
        notifyListeners();
      });
    }
    
    // Auto-logout
    _logoutTimer = Timer(Duration(minutes: _sessionTimeoutMinutes), () {
      _isLocked = true;
      notifyListeners();
    });
  }

  /// Lock the app (require re-authentication)
  void lockApp() {
    _isLocked = true;
    notifyListeners();
  }

  /// Unlock the app
  void unlockApp() {
    _isLocked = false;
    _resetActivityTimer();
    notifyListeners();
  }

  /// Save PIN for auto-login (hashed)
  Future<void> savePinHash(String pinHash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, pinHash);
  }

  /// Check if saved PIN matches
  Future<bool> checkSavedPin(String pinHash) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyPinHash);
    return saved == pinHash;
  }

  /// Clear saved PIN
  Future<void> clearSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
  }

  /// Enable/disable auto-login
  Future<void> setAutoLogin(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoLogin, enabled);
    notifyListeners();
  }

  Future<bool> getAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoLogin) ?? false;
  }

  @override
  void dispose() {
    _logoutTimer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }
}
