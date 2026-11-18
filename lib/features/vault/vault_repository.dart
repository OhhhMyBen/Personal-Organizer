import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/models/models.dart';

class VaultRepository {
  VaultRepository._();
  static final VaultRepository instance = VaultRepository._();

  static const _vaultKey = 'vault_accounts_v1';
  static const _pinKey = 'vault_pin_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<List<AccountEntry>> loadAccounts() async {
    try {
      final raw = await _storage.read(key: _vaultKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AccountEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccounts(List<AccountEntry> accounts) async {
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _vaultKey, value: encoded);
  }

  Future<String?> loadPin() async {
    try {
      return await _storage.read(key: _pinKey);
    } catch (_) {
      return null;
    }
  }

  /// Sets the 4-digit PIN only if one has not been set yet. Cannot be changed once set.
  Future<bool> setPinOnce(String pin) async {
    final existing = await loadPin();
    if (existing != null && existing.isNotEmpty) {
      return false;
    }
    await _storage.write(key: _pinKey, value: pin);
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final existing = await loadPin();
    return existing != null && existing == pin;
  }

  Future<void> clearVault() async {
    await _storage.delete(key: _vaultKey);
    await _storage.delete(key: _pinKey);
  }
}
