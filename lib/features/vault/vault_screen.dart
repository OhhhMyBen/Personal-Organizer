import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../shared/quick_add_sheet.dart';
import 'vault_provider.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _searchCtrl = TextEditingController();
  final _pinUnlockCtrl = TextEditingController();
  final Set<String> _revealedIds = {};
  String? _pinError;

  static const _categories = [
    'All',
    'Gmail & Google',
    'Gaming',
    'Banking & Bills',
    'Other',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pinUnlockCtrl.dispose();
    super.dispose();
  }

  Future<void> _showSetPinOnceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _SetPinOnceDialog(
        onApply: (pin) => ref.read(vaultProvider.notifier).setPinOnce(pin),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? '4-digit Vault PIN applied permanently ✓'
                : 'Vault PIN is already set and cannot be changed.',
          ),
        ),
      );
    }
  }

  (IconData, Color) _iconForCategory(String cat) {
    return switch (cat) {
      'Gmail & Google' => (Icons.mail_rounded, AppColors.electricBlue),
      'Gaming' => (Icons.sports_esports_rounded, AppColors.emerald),
      'Banking & Bills' => (Icons.credit_card_rounded, AppColors.amber),
      _ => (Icons.lock_rounded, AppColors.purple),
    };
  }

  Future<void> _showAccountEditor({AccountEntry? existing}) async {
    String category = existing?.category ?? 'Gmail & Google';
    final serviceCtrl = TextEditingController(text: existing?.serviceName ?? '');
    final emailCtrl =
        TextEditingController(text: existing?.emailOrUsername ?? '');
    final passCtrl = TextEditingController(text: existing?.passwordOrPin ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool obscure = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'Add Account' : 'Edit Account',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _categories.where((c) => c != 'All').map((c) {
                    final active = category == c;
                    return ChoiceChip(
                      label: Text(c),
                      selected: active,
                      selectedColor: AppColors.purple,
                      onSelected: (_) => setModalState(() => category = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serviceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Service Name',
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email / Username',
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password / PIN',
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          tooltip: 'Generate Password',
                          onPressed: () {
                            const chars =
                                'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';
                            final rng = Random.secure();
                            setModalState(() {
                              passCtrl.text = List.generate(
                                14,
                                (_) => chars[rng.nextInt(chars.length)],
                              ).join();
                              obscure = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes (Recovery email, Server ID, etc.)',
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (serviceCtrl.text.trim().isEmpty) return;
                    final entry = AccountEntry(
                      id: existing?.id ??
                          'acc_${DateTime.now().microsecondsSinceEpoch}',
                      category: category,
                      serviceName: serviceCtrl.text.trim(),
                      emailOrUsername: emailCtrl.text.trim(),
                      passwordOrPin: passCtrl.text,
                      notes: notesCtrl.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    await ref
                        .read(vaultProvider.notifier)
                        .addOrUpdateAccount(entry);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save to Encrypted Vault'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final items = vault.filteredAccounts;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: vault.isUnlocked
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              onPressed: () => showQuickAddSheet(
                context,
                initialTab: QuickAddTab.account,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Account'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Vault',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            vault.hasPin
                                ? 'PIN Protected (Permanent)'
                                : 'Offline Encrypted',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (vault.isUnlocked && !vault.hasPin)
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cardBg,
                          foregroundColor: AppColors.amber,
                        ),
                        tooltip: 'Set 4-Digit PIN (One-time)',
                        onPressed: _showSetPinOnceDialog,
                        icon: const Icon(Icons.pin_rounded),
                      ),
                    if (vault.isUnlocked &&
                        (vault.hasPin || vault.biometricLockEnabled)) ...[
                      const SizedBox(width: 6),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cardBg,
                          foregroundColor: AppColors.purple,
                        ),
                        tooltip: 'Lock Vault',
                        onPressed: () {
                          _pinUnlockCtrl.clear();
                          setState(() => _pinError = null);
                          ref.read(vaultProvider.notifier).lockVault();
                        },
                        icon: const Icon(Icons.lock_rounded),
                      ),
                    ],
                    if (!vault.hasPin) ...[
                      const SizedBox(width: 6),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.cardBg,
                          foregroundColor: AppColors.purple,
                        ),
                        tooltip: vault.biometricLockEnabled
                            ? 'Biometric Lock ON (Tap to disable)'
                            : 'Biometric Lock OFF (Tap to enable)',
                        onPressed: () => ref
                            .read(vaultProvider.notifier)
                            .toggleBiometricLock(),
                        icon: Icon(
                          vault.biometricLockEnabled
                              ? Icons.fingerprint_rounded
                              : Icons.lock_open_rounded,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!vault.isUnlocked)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 56,
                          color: AppColors.purple,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Vault Locked',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vault.hasPin
                              ? 'Enter your 4-digit PIN to unlock'
                              : 'Authenticate to view saved accounts',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (vault.hasPin) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: _pinUnlockCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              obscureText: true,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                letterSpacing: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••',
                                filled: true,
                                fillColor: AppColors.cardBg,
                                errorText: _pinError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (val) async {
                                if (val.length == 4) {
                                  final ok = await ref
                                      .read(vaultProvider.notifier)
                                      .verifyPinAndUnlock(val);
                                  if (!ok && mounted) {
                                    setState(() {
                                      _pinError = 'Incorrect PIN';
                                      _pinUnlockCtrl.clear();
                                    });
                                  }
                                } else if (_pinError != null) {
                                  setState(() => _pinError = null);
                                }
                              },
                            ),
                          ),
                        ],
                        if (vault.biometricLockEnabled) ...[
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await ref
                                  .read(vaultProvider.notifier)
                                  .authenticate();
                              if (!ok) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Biometric authentication cancelled or unavailable on this device.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Unlock with Biometrics'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Search Bar
              TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    ref.read(vaultProvider.notifier).setSearchQuery(v),
                decoration: InputDecoration(
                  hintText: 'Search Gmail, gaming, bank accounts...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(vaultProvider.notifier)
                                .setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Category Filter Pills
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final active = vault.selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: active,
                      selectedColor: AppColors.purple,
                      backgroundColor: AppColors.cardBg,
                      labelStyle: TextStyle(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (_) => ref
                          .read(vaultProvider.notifier)
                          .setSelectedCategory(cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Credentials List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            const Text(
                              'No saved accounts yet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap Add Account to store credentials offline.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, idx) {
                          final acc = items[idx];
                          final (icon, iconColor) =
                              _iconForCategory(acc.category);
                          final revealed = _revealedIds.contains(acc.id);

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.cardElevated,
                                        child: Icon(icon,
                                            color: iconColor, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              acc.serviceName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              acc.category,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded,
                                            size: 18),
                                        onPressed: () =>
                                            _showAccountEditor(existing: acc),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: AppColors.red,
                                        ),
                                        onPressed: () => ref
                                            .read(vaultProvider.notifier)
                                            .deleteAccount(acc.id),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            acc.emailOrUsername,
                                            style:
                                                const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.content_copy_rounded,
                                              size: 16),
                                          onPressed: () =>
                                              _copy(acc.emailOrUsername),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            revealed
                                                ? acc.passwordOrPin
                                                : '••••••••••••',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'monospace',
                                              color: revealed
                                                  ? AppColors.emerald
                                                  : AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            revealed
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 16,
                                          ),
                                          onPressed: () async {
                                            if (!revealed &&
                                                vault.biometricLockEnabled) {
                                              final ok = await ref
                                                  .read(vaultProvider.notifier)
                                                  .authenticate(
                                                    reason:
                                                        'Authenticate to reveal password',
                                                  );
                                              if (!ok) return;
                                            }
                                            setState(() {
                                              if (revealed) {
                                                _revealedIds.remove(acc.id);
                                              } else {
                                                _revealedIds.add(acc.id);
                                              }
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.content_copy_rounded,
                                              size: 16),
                                          onPressed: () =>
                                              _copy(acc.passwordOrPin),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (acc.notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Notes: ${acc.notes}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetPinOnceDialog extends StatefulWidget {
  const _SetPinOnceDialog({required this.onApply});

  final Future<bool> Function(String pin) onApply;

  @override
  State<_SetPinOnceDialog> createState() => _SetPinOnceDialogState();
}

class _SetPinOnceDialogState extends State<_SetPinOnceDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _errorMsg;
  bool _saving = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p1 = _pinCtrl.text.trim();
    final p2 = _confirmCtrl.text.trim();
    if (p1.length != 4) {
      setState(() => _errorMsg = 'PIN must be 4 digits.');
      return;
    }
    if (p1 != p2) {
      setState(() => _errorMsg = 'PINs do not match.');
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onApply(p1);
    if (mounted) {
      Navigator.pop(context, ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Set 4-Digit Vault PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'One-time setup: Once applied, this 4-digit PIN cannot be changed.',
            style: TextStyle(fontSize: 12, color: AppColors.amber),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Enter 4-Digit PIN',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Confirm 4-Digit PIN',
              counterText: '',
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: const TextStyle(color: AppColors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _submit,
          child: const Text('Apply PIN'),
        ),
      ],
    );
  }
}
