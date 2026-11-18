import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/models.dart';
import 'vault_repository.dart';

class VaultState {
  const VaultState({
    required this.accounts,
    this.biometricLockEnabled = false,
    this.hasPin = false,
    this.isUnlocked = true,
    this.canUseBiometrics = false,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.isLoading = false,
  });

  final List<AccountEntry> accounts;
  final bool biometricLockEnabled;
  final bool hasPin;
  final bool isUnlocked;
  final bool canUseBiometrics;
  final String searchQuery;
  final String selectedCategory;
  final bool isLoading;

  List<AccountEntry> get filteredAccounts {
    final q = searchQuery.trim().toLowerCase();
    return accounts.where((a) {
      final catMatch =
          selectedCategory == 'All' || a.category == selectedCategory;
      final qMatch = q.isEmpty ||
          a.serviceName.toLowerCase().contains(q) ||
          a.emailOrUsername.toLowerCase().contains(q) ||
          a.notes.toLowerCase().contains(q);
      return catMatch && qMatch;
    }).toList();
  }

  VaultState copyWith({
    List<AccountEntry>? accounts,
    bool? biometricLockEnabled,
    bool? hasPin,
    bool? isUnlocked,
    bool? canUseBiometrics,
    String? searchQuery,
    String? selectedCategory,
    bool? isLoading,
  }) {
    return VaultState(
      accounts: accounts ?? this.accounts,
      biometricLockEnabled: biometricLockEnabled ?? this.biometricLockEnabled,
      hasPin: hasPin ?? this.hasPin,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class VaultNotifier extends Notifier<VaultState> {
  static const _lockPrefKey = 'vault_biometric_lock';
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  VaultState build() {
    Future.microtask(load);
    return const VaultState(accounts: [], isLoading: true);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lockEnabled = prefs.getBool(_lockPrefKey) ?? false;
    final pin = await VaultRepository.instance.loadPin();
    final hasPin = pin != null && pin.length == 4;

    bool canBio = false;
    try {
      canBio = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      canBio = false;
    }

    final accounts = await VaultRepository.instance.loadAccounts();
    state = VaultState(
      accounts: accounts,
      biometricLockEnabled: lockEnabled,
      hasPin: hasPin,
      isUnlocked: !(lockEnabled || hasPin),
      canUseBiometrics: canBio,
      isLoading: false,
    );
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<bool> setPinOnce(String pin) async {
    final ok = await VaultRepository.instance.setPinOnce(pin);
    if (ok) {
      state = state.copyWith(hasPin: true, isUnlocked: true);
    }
    return ok;
  }

  Future<bool> verifyPinAndUnlock(String pin) async {
    final ok = await VaultRepository.instance.verifyPin(pin);
    if (ok) {
      state = state.copyWith(isUnlocked: true);
    }
    return ok;
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to view saved accounts',
  }) async {
    if (!state.biometricLockEnabled && !state.hasPin) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: reason,
      );
      if (didAuth) {
        state = state.copyWith(isUnlocked: true);
      }
      return didAuth;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleBiometricLock() async {
    final next = !state.biometricLockEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockPrefKey, next);
    state = state.copyWith(
      biometricLockEnabled: next,
      isUnlocked: !(next || state.hasPin),
    );
  }

  void lockVault() {
    if (state.biometricLockEnabled || state.hasPin) {
      state = state.copyWith(isUnlocked: false);
    }
  }

  Future<void> addOrUpdateAccount(AccountEntry entry) async {
    final updated = List<AccountEntry>.from(state.accounts);
    final idx = updated.indexWhere((a) => a.id == entry.id);
    if (idx != -1) {
      updated[idx] = entry;
    } else {
      updated.insert(0, entry);
    }
    await VaultRepository.instance.saveAccounts(updated);
    state = state.copyWith(accounts: updated);
  }

  Future<void> deleteAccount(String id) async {
    final updated = state.accounts.where((a) => a.id != id).toList();
    await VaultRepository.instance.saveAccounts(updated);
    state = state.copyWith(accounts: updated);
  }
}

final vaultProvider =
    NotifierProvider<VaultNotifier, VaultState>(VaultNotifier.new);
