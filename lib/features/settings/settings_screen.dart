import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../budget/budget_provider.dart';
import '../calendar/calendar_provider.dart';
import '../tasks/tasks_provider.dart';
import '../vault/vault_provider.dart';
import '../vault/vault_repository.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'is_dark_mode';

  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all recurring bills, expenses, income, special days, tasks, and encrypted vault accounts (including any Vault PIN). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AppDatabase.instance.clearAllData();
    await VaultRepository.instance.clearVault();

    final prefs = await SharedPreferences.getInstance();
    final keepDark = prefs.getBool('is_dark_mode') ?? true;
    await prefs.clear();
    await prefs.setBool('is_dark_mode', keepDark);

    await ref.read(budgetProvider.notifier).load();
    await ref.read(calendarProvider.notifier).load();
    await ref.read(tasksProvider.notifier).load();
    await ref.read(vaultProvider.notifier).load();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared. Fresh start ready!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance
          Card(
            child: SwitchListTile(
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isDark ? 'Dark theme enabled' : 'Light theme enabled',
              ),
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.electricBlue,
              ),
              value: isDark,
              activeThumbColor: AppColors.emerald,
              onChanged: (v) =>
                  ref.read(themeModeProvider.notifier).toggleDarkMode(v),
            ),
          ),
          const SizedBox(height: 16),

          // Short App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.emerald),
                      SizedBox(width: 10),
                      Text(
                        'Offline Personal Life Organizer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'A 100% offline-first personal life organizer for managing your monthly budget, recurring bills, income, expenses, calendar events & birthdays, tasks, and encrypted account credentials. All data is stored locally on your device—no cloud sync or login required.',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Clear All Data
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: AppColors.red),
              title: const Text(
                'Clear All Data (Fresh Start)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ),
              ),
              subtitle: const Text(
                'Reset SQLite database, budget settings, and encrypted vault.',
              ),
              onTap: () => _confirmClearAll(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
