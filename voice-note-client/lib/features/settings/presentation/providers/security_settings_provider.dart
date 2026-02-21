import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/network_providers.dart';

part 'security_settings_provider.g.dart';

const _keyGestureLockEnabled = 'key_gesture_lock_enabled';
const _keyPasswordLockEnabled = 'key_password_lock_enabled';
const _keyEncryptedGesture = 'key_encrypted_gesture';
const _keyEncryptedPassword = 'key_encrypted_password';

@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}

/// In-memory + persisted state for app lock.
class SecuritySettingsState {
  const SecuritySettingsState({
    this.isGestureLockEnabled = false,
    this.isPasswordLockEnabled = false,
    this.isUnlockedThisSession = false,
  });

  final bool isGestureLockEnabled;
  final bool isPasswordLockEnabled;
  final bool isUnlockedThisSession;

  SecuritySettingsState copyWith({
    bool? isGestureLockEnabled,
    bool? isPasswordLockEnabled,
    bool? isUnlockedThisSession,
  }) {
    return SecuritySettingsState(
      isGestureLockEnabled: isGestureLockEnabled ?? this.isGestureLockEnabled,
      isPasswordLockEnabled: isPasswordLockEnabled ?? this.isPasswordLockEnabled,
      isUnlockedThisSession:
          isUnlockedThisSession ?? this.isUnlockedThisSession,
    );
  }

  bool get isLockEnabled =>
      isGestureLockEnabled || isPasswordLockEnabled;
}

String _sha256(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

@Riverpod(keepAlive: true)
class SecuritySettings extends _$SecuritySettings {
  @override
  SecuritySettingsState build() {
    return const SecuritySettingsState();
  }

  Future<void> initSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final gesture = prefs.getBool(_keyGestureLockEnabled) ?? false;
    final password = prefs.getBool(_keyPasswordLockEnabled) ?? false;
    state = state.copyWith(
      isGestureLockEnabled: gesture,
      isPasswordLockEnabled: password,
    );
  }

  Future<void> setGestureLockEnabled(bool value, String? hashedPattern) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final storage = ref.read(secureStorageProvider);
    if (value && hashedPattern != null) {
      await prefs.setBool(_keyGestureLockEnabled, true);
      await storage.write(key: _keyEncryptedGesture, value: hashedPattern);
    } else {
      await prefs.setBool(_keyGestureLockEnabled, false);
      await storage.delete(key: _keyEncryptedGesture);
    }
    state = state.copyWith(isGestureLockEnabled: value);
  }

  Future<void> setPasswordLockEnabled(bool value, String? hashedPassword) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final storage = ref.read(secureStorageProvider);
    if (value && hashedPassword != null) {
      await prefs.setBool(_keyPasswordLockEnabled, true);
      await storage.write(key: _keyEncryptedPassword, value: hashedPassword);
    } else {
      await prefs.setBool(_keyPasswordLockEnabled, false);
      await storage.delete(key: _keyEncryptedPassword);
    }
    state = state.copyWith(isPasswordLockEnabled: value);
  }

  Future<bool> verifyGesture(String pattern) async {
    final storage = ref.read(secureStorageProvider);
    final stored = await storage.read(key: _keyEncryptedGesture);
    if (stored == null) return false;
    return _sha256(pattern) == stored;
  }

  Future<bool> verifyPassword(String password) async {
    final storage = ref.read(secureStorageProvider);
    final stored = await storage.read(key: _keyEncryptedPassword);
    if (stored == null) return false;
    return _sha256(password) == stored;
  }

  void clearUnlockedThisSession() {
    state = state.copyWith(isUnlockedThisSession: false);
  }

  void setUnlockedThisSession() {
    state = state.copyWith(isUnlockedThisSession: true);
  }

  static String hashGesturePattern(String pattern) => _sha256(pattern);
  static String hashPassword(String password) => _sha256(password);
}
