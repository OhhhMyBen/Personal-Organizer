import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../budget/budget_provider.dart';
import '../calendar/calendar_provider.dart';
import '../tasks/tasks_provider.dart';
import '../vault/vault_provider.dart';

enum QuickAddTab { recurringBill, expense, income, birthday, task, account }

Future<void> showQuickAddSheet(
  BuildContext context, {
  QuickAddTab initialTab = QuickAddTab.recurringBill,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuickAddSheet(initialTab: initialTab),
  );
}

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialTab = QuickAddTab.recurringBill,
  });

  final QuickAddTab initialTab;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late QuickAddTab _tab;

  // Shared / Bill / Expense / Income
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();

  bool _isVariable = false;
  int _dueDay = 5;
  bool _remindBill = true;

  String _billCategory = 'Transportation / Gas';
  bool _isCustomBillCategory = false;

  String _expenseCategory = 'Food';
  bool _isCustomExpenseCategory = false;
  DateTime _expenseDate = DateTime.now();

  String _incomeCategory = 'Salary';
  bool _isCustomIncomeCategory = false;
  DateTime _incomeDate = DateTime.now();

  // Birthday / Special Day / Recurring Event
  String _specialType = 'birthday';
  String _specialRecurrence = 'yearly';
  int _specialMonth = DateTime.now().month;
  int _specialDay = DateTime.now().day;
  final _birthYearController = TextEditingController();
  bool _notifyDayBefore = true;

  // Task
  DateTime? _taskDueDate = DateTime.now();
  int _taskPriority = 2;
  String _taskCategory = 'Personal';

  // Account
  String _accountCategory = 'Gmail & Google';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const _billCategories = [
    'Transportation / Gas',
    'Utilities',
    'Subscriptions',
    'Rent & Housing',
    'Custom...',
  ];

  static const _expenseCategories = [
    'Food',
    'Gas/Fuel',
    'Utilities',
    'Gaming',
    'Shopping',
    'Misc',
  ];

  static const _incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Gift / Bonus',
    'Allowance',
  ];

  static const _taskCategories = ['Personal', 'Finance', 'Work', 'Errands'];

  static const _accountCategories = [
    'Gmail & Google',
    'Gaming',
    'Banking & Bills',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    _birthYearController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    return switch (d % 10) {
      1 => '${d}st',
      2 => '${d}nd',
      3 => '${d}rd',
      _ => '${d}th',
    };
  }

  void _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*';
    final rng = Random.secure();
    final generated =
        List.generate(14, (_) => chars[rng.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  Future<void> _openDueDayGridPicker() async {
    FocusScope.of(context).unfocus();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Select Monthly Due Day',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 31,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (_, idx) {
                  final day = idx + 1;
                  final selected = day == _dueDay;
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, day),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.amber
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.black : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Short months (e.g. Feb) automatically clamp to month-end.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dueDay = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title / name')),
      );
      return;
    }

    switch (_tab) {
      case QuickAddTab.recurringBill:
        final amt =
            double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
                0.0;
        if (amt <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid ₱ amount')),
          );
          return;
        }
        final customCat = _customCategoryController.text.trim();
        final finalCat = (_isCustomBillCategory && customCat.isNotEmpty)
            ? customCat
            : (_isCustomBillCategory ? 'Other' : _billCategory);

        await ref.read(budgetProvider.notifier).addRecurringBill(
              title: title,
              amount: amt,
              isVariable: _isVariable,
              dueDay: _dueDay,
              category: finalCat,
              notifyDaysBefore: _remindBill ? 1 : 0,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved bill "$title" & scheduled reminder')),
          );
        }
        break;

      case QuickAddTab.expense:
        final amt =
            double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
                0.0;
        if (amt <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid ₱ amount')),
          );
          return;
        }
        final customCat = _customCategoryController.text.trim();
        final finalCat = (_isCustomExpenseCategory && customCat.isNotEmpty)
            ? customCat
            : _expenseCategory;

        await ref.read(budgetProvider.notifier).addExpense(
              title: title,
              amount: amt,
              category: finalCat,
              date: _expenseDate,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logged expense ${formatCurrency(amt)}')),
          );
        }
        break;

      case QuickAddTab.income:
        final amt =
            double.tryParse(_amountController.text.replaceAll(',', '').trim()) ??
                0.0;
        if (amt <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid ₱ amount')),
          );
          return;
        }
        final customCat = _customCategoryController.text.trim();
        final finalCat = (_isCustomIncomeCategory && customCat.isNotEmpty)
            ? customCat
            : _incomeCategory;

        await ref.read(budgetProvider.notifier).addIncome(
              title: title,
              amount: amt,
              category: finalCat,
              date: _incomeDate,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logged income +${formatCurrency(amt)}')),
          );
        }
        break;

      case QuickAddTab.birthday:
        final year = int.tryParse(_birthYearController.text.trim());
        await ref.read(calendarProvider.notifier).addSpecialDay(
              title: title,
              type: _specialType,
              month: _specialMonth,
              day: _specialDay,
              year: year ?? (_specialRecurrence == 'weekly' || _specialRecurrence == 'once' ? DateTime.now().year : null),
              notifyDayBefore: _notifyDayBefore,
              recurrence: _specialRecurrence,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved "$title" (${_notifyDayBefore ? "1-day advance alert set" : "no alert"})',
              ),
            ),
          );
        }
        break;

      case QuickAddTab.task:
        await ref.read(tasksProvider.notifier).addTask(
              title: title,
              dueDate: _taskDueDate,
              priority: _taskPriority,
              category: _taskCategory,
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task added: $title')),
          );
        }
        break;

      case QuickAddTab.account:
        final entry = AccountEntry(
          id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
          category: _accountCategory,
          serviceName: title,
          emailOrUsername: _emailController.text.trim(),
          passwordOrPin: _passwordController.text,
          notes: _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );
        await ref.read(vaultProvider.notifier).addOrUpdateAccount(entry);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Encrypted & saved "$title" to Vault')),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: RepaintBoundary(
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quick Add',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _tabChip(QuickAddTab.recurringBill, 'Recurring Bill',
                          AppColors.amber),
                      const SizedBox(width: 8),
                      _tabChip(
                          QuickAddTab.expense, 'Expense', AppColors.red),
                      const SizedBox(width: 8),
                      _tabChip(
                          QuickAddTab.income, 'Income', AppColors.emerald),
                      const SizedBox(width: 8),
                      _tabChip(QuickAddTab.birthday, 'Event / B-day',
                          AppColors.electricBlue),
                      const SizedBox(width: 8),
                      _tabChip(
                          QuickAddTab.task, 'Task', AppColors.electricBlue),
                      const SizedBox(width: 8),
                      _tabChip(
                          QuickAddTab.account, 'Account', AppColors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_tab == QuickAddTab.recurringBill)
                  ..._buildRecurringBillForm(),
                if (_tab == QuickAddTab.expense) ..._buildExpenseForm(),
                if (_tab == QuickAddTab.income) ..._buildIncomeForm(),
                if (_tab == QuickAddTab.birthday) ..._buildBirthdayForm(),
                if (_tab == QuickAddTab.task) ..._buildTaskForm(),
                if (_tab == QuickAddTab.account) ..._buildAccountForm(),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentForTab(_tab),
                      foregroundColor:
                          _tab == QuickAddTab.account ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _saveLabel(_tab),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentForTab(QuickAddTab t) => switch (t) {
        QuickAddTab.recurringBill => AppColors.amber,
        QuickAddTab.expense => AppColors.red,
        QuickAddTab.income => AppColors.emerald,
        QuickAddTab.birthday => AppColors.electricBlue,
        QuickAddTab.task => AppColors.electricBlue,
        QuickAddTab.account => AppColors.purple,
      };

  String _saveLabel(QuickAddTab t) => switch (t) {
        QuickAddTab.recurringBill => 'Save Recurring Bill',
        QuickAddTab.expense => 'Save Expense',
        QuickAddTab.income => 'Save Income',
        QuickAddTab.birthday => 'Save Special Day',
        QuickAddTab.task => 'Save Task',
        QuickAddTab.account => 'Encrypt & Save Account',
      };

  Widget _tabChip(QuickAddTab tab, String label, Color color) {
    final active = _tab == tab;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: color,
      backgroundColor: AppColors.cardElevated,
      labelStyle: TextStyle(
        color: active
            ? (tab == QuickAddTab.account ? Colors.white : Colors.black)
            : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _tab = tab),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.inputBg,
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRecurringBillForm() {
    const quickDays = [1, 5, 10, 15, 20, 24, 28, 30];

    return [
      _inputField(
        controller: _titleController,
        label: 'Bill Title',
        hint: 'e.g. Atome Bank (Gas), PLDT Home Fiber',
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _amountController,
        label: 'Amount (₱)',
        hint: '1400.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Variable Amount (changes monthly)'),
        value: _isVariable,
        activeThumbColor: AppColors.amber,
        onChanged: (v) => setState(() => _isVariable = v),
      ),
      const SizedBox(height: 6),

      // Improved Tactile Due Day Picker
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Schedule Due Day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          InkWell(
            onTap: _openDueDayGridPicker,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 14, color: AppColors.amber),
                  const SizedBox(width: 5),
                  Text(
                    'Every ${_ordinal(_dueDay)} • Tap for 1–31',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ...quickDays.map((d) {
              final active = d == _dueDay;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _dueDay = d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: active ? AppColors.amber : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.amber : AppColors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          active ? 'DUE' : 'DAY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.black87
                                : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color:
                                active ? Colors.black : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            InkWell(
              onTap: _openDueDayGridPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.apps_rounded,
                        size: 18, color: AppColors.amber),
                    SizedBox(width: 6),
                    Text(
                      'All Days',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      DropdownButtonFormField<String>(
        initialValue: _billCategory,
        dropdownColor: AppColors.cardElevated,
        decoration: InputDecoration(
          labelText: 'Category',
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: _billCategories
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) {
          setState(() {
            _billCategory = v ?? _billCategories.first;
            _isCustomBillCategory = _billCategory == 'Custom...';
          });
        },
      ),
      if (_isCustomBillCategory) ...[
        const SizedBox(height: 10),
        _inputField(
          controller: _customCategoryController,
          label: 'Custom Category Name',
          hint: 'e.g. Health Insurance, Gym, Loan',
        ),
      ],
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Remind 1 day before & on due date'),
        value: _remindBill,
        activeThumbColor: AppColors.emerald,
        onChanged: (v) => setState(() => _remindBill = v),
      ),
    ];
  }

  List<Widget> _buildExpenseForm() {
    return [
      _inputField(
        controller: _titleController,
        label: 'Expense Title',
        hint: 'e.g. Yardstick Coffee, Groceries',
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _amountController,
        label: 'Amount (₱)',
        hint: '250.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 12),
      const Text(
        'Category',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          ..._expenseCategories.map((cat) {
            final active = !_isCustomExpenseCategory && _expenseCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: active,
              selectedColor: AppColors.red,
              backgroundColor: AppColors.cardElevated,
              labelStyle: TextStyle(
                color: active ? Colors.black : AppColors.textSecondary,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() {
                _expenseCategory = cat;
                _isCustomExpenseCategory = false;
              }),
            );
          }),
          ChoiceChip(
            label: const Text('+ Custom'),
            selected: _isCustomExpenseCategory,
            selectedColor: AppColors.red,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: _isCustomExpenseCategory
                  ? Colors.black
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _isCustomExpenseCategory = true),
          ),
        ],
      ),
      if (_isCustomExpenseCategory) ...[
        const SizedBox(height: 10),
        _inputField(
          controller: _customCategoryController,
          label: 'Custom Category',
          hint: 'e.g. Pets, Coffee, Healthcare',
        ),
      ],
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Date'),
        subtitle: Text(DateFormat('MMM d, yyyy').format(_expenseDate)),
        trailing: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _expenseDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _expenseDate = picked);
          },
          child: const Text('Change'),
        ),
      ),
      _inputField(
        controller: _notesController,
        label: 'Notes (Optional)',
        hint: 'Payment method or details',
      ),
    ];
  }

  List<Widget> _buildIncomeForm() {
    return [
      _inputField(
        controller: _titleController,
        label: 'Income Source / Title',
        hint: 'e.g. Monthly Salary, Freelance Payout',
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _amountController,
        label: 'Amount Received (₱)',
        hint: '5000.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 12),
      const Text(
        'Category',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          ..._incomeCategories.map((cat) {
            final active = !_isCustomIncomeCategory && _incomeCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: active,
              selectedColor: AppColors.emerald,
              backgroundColor: AppColors.cardElevated,
              labelStyle: TextStyle(
                color: active ? Colors.black : AppColors.textSecondary,
                fontSize: 12,
              ),
              onSelected: (_) => setState(() {
                _incomeCategory = cat;
                _isCustomIncomeCategory = false;
              }),
            );
          }),
          ChoiceChip(
            label: const Text('+ Custom'),
            selected: _isCustomIncomeCategory,
            selectedColor: AppColors.emerald,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: _isCustomIncomeCategory
                  ? Colors.black
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _isCustomIncomeCategory = true),
          ),
        ],
      ),
      if (_isCustomIncomeCategory) ...[
        const SizedBox(height: 10),
        _inputField(
          controller: _customCategoryController,
          label: 'Custom Category',
          hint: 'e.g. Dividends, Side Hustle, Refund',
        ),
      ],
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Date Received'),
        subtitle: Text(DateFormat('MMM d, yyyy').format(_incomeDate)),
        trailing: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _incomeDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _incomeDate = picked);
          },
          child: const Text('Change'),
        ),
      ),
      _inputField(
        controller: _notesController,
        label: 'Notes (Optional)',
        hint: 'Bank account or reference',
      ),
    ];
  }

  List<Widget> _buildBirthdayForm() {
    return [
      _inputField(
        controller: _titleController,
        label: "Title / Person's Name",
        hint: "e.g. Mom's Birthday",
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          ('birthday', 'Birthday'),
          ('anniversary', 'Anniversary'),
          ('event', 'Recurring Event'),
        ].map((pair) {
          final active = _specialType == pair.$1;
          return ChoiceChip(
            label: Text(pair.$2),
            selected: active,
            selectedColor: AppColors.electricBlue,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: active ? Colors.black : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() {
              _specialType = pair.$1;
              if (_specialType == 'event' && _specialRecurrence == 'yearly') {
                _specialRecurrence = 'monthly';
              }
            }),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      const Text(
        'Recurrence',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          ('yearly', 'Yearly'),
          ('monthly', 'Monthly'),
          ('weekly', 'Weekly'),
          ('once', 'One-time'),
        ].map((pair) {
          final active = _specialRecurrence == pair.$1;
          return ChoiceChip(
            label: Text(pair.$2),
            selected: active,
            selectedColor: AppColors.purple,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _specialRecurrence = pair.$1),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _specialMonth,
              dropdownColor: AppColors.cardElevated,
              decoration: InputDecoration(
                labelText: 'Month',
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(DateFormat('MMMM').format(DateTime(2026, i + 1))),
                ),
              ),
              onChanged: (v) => setState(() => _specialMonth = v ?? 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _specialDay,
              dropdownColor: AppColors.cardElevated,
              decoration: InputDecoration(
                labelText: 'Day',
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: List.generate(
                31,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (v) => setState(() => _specialDay = v ?? 1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _birthYearController,
        label: 'Birth Year (Optional)',
        hint: 'e.g. 1968',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Notify me 1 day before (8:00 AM)'),
        value: _notifyDayBefore,
        activeThumbColor: AppColors.electricBlue,
        onChanged: (v) => setState(() => _notifyDayBefore = v),
      ),
    ];
  }

  List<Widget> _buildTaskForm() {
    return [
      _inputField(
        controller: _titleController,
        label: 'Task Title',
        hint: 'e.g. Pay Atome Gas bill',
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Priority: ',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          ...[
            (1, 'Low', AppColors.textSecondary),
            (2, 'Med', AppColors.amber),
            (3, 'High', AppColors.red),
          ].map((p) {
            final active = _taskPriority == p.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.$2),
                selected: active,
                selectedColor: p.$3,
                backgroundColor: AppColors.cardElevated,
                labelStyle: TextStyle(
                  color: active ? Colors.black : AppColors.textSecondary,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _taskPriority = p.$1),
              ),
            );
          }),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: _taskCategories.map((cat) {
          final active = _taskCategory == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: active,
            selectedColor: AppColors.electricBlue,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: active ? Colors.black : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _taskCategory = cat),
          );
        }).toList(),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Due Date'),
        subtitle: Text(
          _taskDueDate == null
              ? 'No due date'
              : DateFormat('MMM d, yyyy').format(_taskDueDate!),
        ),
        trailing: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _taskDueDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _taskDueDate = picked);
          },
          child: const Text('Pick Date'),
        ),
      ),
    ];
  }

  List<Widget> _buildAccountForm() {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _accountCategories.map((cat) {
          final active = _accountCategory == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: active,
            selectedColor: AppColors.purple,
            backgroundColor: AppColors.cardElevated,
            labelStyle: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _accountCategory = cat),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _titleController,
        label: 'Service Name',
        hint: 'e.g. Main Gmail, Mobile Legends, Atome',
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _emailController,
        label: 'Email / Username',
        hint: 'e.g. user@gmail.com',
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _passwordController,
        label: 'Password / PIN',
        hint: 'Stored in encrypted local storage',
        obscure: _obscurePassword,
        suffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            IconButton(
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              tooltip: 'Generate strong password',
              onPressed: _generatePassword,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _inputField(
        controller: _notesController,
        label: 'Notes (Optional)',
        hint: 'Recovery email, backup codes, server ID...',
      ),
    ];
  }
}
