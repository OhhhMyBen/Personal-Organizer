import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../shared/quick_add_sheet.dart';
import 'analytics_view.dart';
import 'bill_payment_dialog.dart';
import 'budget_provider.dart';

enum _BudgetSegment { bills, expenses, income, analytics }

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  _BudgetSegment _segment = _BudgetSegment.bills;

  String _ordinal(int d) {
    if (d >= 11 && d <= 13) return '${d}th';
    return switch (d % 10) {
      1 => '${d}st',
      2 => '${d}nd',
      3 => '${d}rd',
      _ => '${d}th',
    };
  }

  int _daysUntilDue(int dueDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    var due = DateTime(now.year, now.month, dueDay.clamp(1, lastDay));
    if (due.isBefore(today)) {
      final next = DateTime(now.year, now.month + 1, 1);
      final nextLast = DateTime(next.year, next.month + 1, 0).day;
      due = DateTime(next.year, next.month, dueDay.clamp(1, nextLast));
    }
    return due.difference(today).inDays;
  }

  Future<void> _promptEditBillAmount(RecurringBill bill) async {
    final ctrl = TextEditingController(text: bill.amount.toStringAsFixed(2));
    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text('Edit ${bill.title}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₱ ',
            labelText: 'Expected / Actual Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '').trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (updated != null && updated > 0) {
      await ref.read(budgetProvider.notifier).updateBillAmount(bill, updated);
    }
  }

  Future<void> _handleMarkPaid(RecurringBill bill) =>
      confirmAndMarkBillPaid(context, ref, bill);

  Future<void> _promptEditBudgetLimit(double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Edit Monthly Budget Limit'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₱ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '').trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != null && updated > 0) {
      await ref.read(budgetProvider.notifier).setMonthlyBudgetLimit(updated);
    }
  }

  String _groupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: _segment == _BudgetSegment.analytics
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _segment == _BudgetSegment.income
                  ? AppColors.emerald
                  : (_segment == _BudgetSegment.expenses
                      ? AppColors.red
                      : AppColors.emerald),
              foregroundColor: Colors.black,
              onPressed: () => showQuickAddSheet(
                context,
                initialTab: switch (_segment) {
                  _BudgetSegment.bills => QuickAddTab.recurringBill,
                  _BudgetSegment.expenses => QuickAddTab.expense,
                  _BudgetSegment.income => QuickAddTab.income,
                  _BudgetSegment.analytics => QuickAddTab.expense,
                },
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(switch (_segment) {
                _BudgetSegment.bills => 'Add Bill',
                _BudgetSegment.expenses => 'Add Expense',
                _BudgetSegment.income => 'Add Income',
                _BudgetSegment.analytics => '',
              }),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Budget & Bills',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                InkWell(
                  onTap: () =>
                      _promptEditBudgetLimit(budget.monthlyBudgetLimit),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      'Limit: ${formatCurrency(budget.monthlyBudgetLimit, showDecimals: false)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Segmented Switcher (Bills | Expenses | Income | Analytics)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  _segTab(_BudgetSegment.bills, 'Bills'),
                  _segTab(_BudgetSegment.expenses, 'Expenses'),
                  _segTab(_BudgetSegment.income, 'Income'),
                  _segTab(_BudgetSegment.analytics, 'Analytics'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary Row
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(budget.remainingBudget),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upcoming Bills',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(budget.upcomingBillsTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_segment == _BudgetSegment.bills) ...[
              ...budget.recurringBills.map((bill) {
                final isPaid = budget.isBillPaidForCurrentMonth(bill);
                final daysLeft = _daysUntilDue(bill.dueDay);
                final countdownText = isPaid
                    ? 'Paid ✓'
                    : (daysLeft == 0 ? 'Due Today' : 'Due in $daysLeft days');
                final countdownColor = isPaid
                    ? AppColors.emerald
                    : (daysLeft == 0 ? AppColors.red : AppColors.amber);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey(bill.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => ref
                        .read(budgetProvider.notifier)
                        .deleteRecurringBill(bill.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_rounded,
                          color: AppColors.red),
                    ),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bill.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Every ${_ordinal(bill.dueDay)} of the month • ${bill.category}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${bill.isVariable ? "~" : ""}${formatCurrency(bill.amount)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.cardElevated,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            bill.isVariable
                                                ? 'Variable'
                                                : 'Fixed',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: countdownColor.withValues(
                                                alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            countdownText,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: countdownColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!isPaid) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _promptEditBillAmount(bill),
                                      icon: const Icon(Icons.edit_rounded,
                                          size: 16),
                                      label: const Text('Edit Amount'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.emerald,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () => _handleMarkPaid(bill),
                                      icon: const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Mark Paid'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ] else if (_segment == _BudgetSegment.expenses) ...[
              // Category Breakdown Card
              _CategoryBreakdownCard(
                breakdown: budget.categoryBreakdown,
                totalSpent: budget.totalSpentThisMonth,
              ),
              const SizedBox(height: 16),
              if (budget.expenses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No expenses logged yet. Tap Add Expense below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...List.generate(budget.expenses.length, (i) {
                  final exp = budget.expenses[i];
                  final label = _groupLabel(exp.date);
                  final showHeader =
                      i == 0 || _groupLabel(budget.expenses[i - 1].date) != label;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(exp.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => ref
                              .read(budgetProvider.notifier)
                              .deleteExpense(exp.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: AppColors.red),
                          ),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.cardElevated,
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.emerald,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                exp.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                exp.notes != null
                                    ? '${exp.category} • ${exp.notes}'
                                    : exp.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Text(
                                '-${formatCurrency(exp.amount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ] else if (_segment == _BudgetSegment.income) ...[
              if (budget.incomes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No income logged yet. Tap Add Income below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...List.generate(budget.incomes.length, (i) {
                  final inc = budget.incomes[i];
                  final label = _groupLabel(inc.date);
                  final showHeader =
                      i == 0 || _groupLabel(budget.incomes[i - 1].date) != label;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(inc.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => ref
                              .read(budgetProvider.notifier)
                              .deleteIncome(inc.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: AppColors.red),
                          ),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.cardElevated,
                                child: const Icon(
                                  Icons.south_west_rounded,
                                  color: AppColors.emerald,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                inc.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                inc.notes != null
                                    ? '${inc.category} • ${inc.notes}'
                                    : inc.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Text(
                                '+${formatCurrency(inc.amount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ] else ...[
              BudgetAnalyticsView(budget: budget),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segTab(_BudgetSegment seg, String label) {
    final active = _segment == seg;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _segment = seg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.breakdown,
    required this.totalSpent,
  });

  final Map<String, double> breakdown;
  final double totalSpent;

  static const _palette = [
    AppColors.emerald,
    AppColors.electricBlue,
    AppColors.amber,
    AppColors.purple,
    AppColors.red,
    AppColors.textSecondary,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown (This Month)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty || totalSpent <= 0)
              const Text(
                'Log expenses to see dynamic category distribution.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: List.generate(entries.length, (i) {
                      final pct =
                          ((entries[i].value / totalSpent) * 100).round().clamp(1, 100);
                      return Expanded(
                        flex: pct,
                        child: Container(color: _palette[i % _palette.length]),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: List.generate(entries.length, (i) {
                  final e = entries[i];
                  final pct = ((e.value / totalSpent) * 100).round();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.key} ($pct%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
