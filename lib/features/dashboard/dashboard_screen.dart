import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../budget/bill_payment_dialog.dart';
import '../budget/budget_provider.dart';
import '../calendar/calendar_provider.dart';
import '../settings/settings_screen.dart';
import '../shared/quick_add_sheet.dart';
import '../shell/main_shell.dart';
import '../tasks/tasks_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  DateTime _nextBillDate(int dueDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDayThisMonth = DateTime(now.year, now.month + 1, 0).day;
    var candidate =
        DateTime(now.year, now.month, dueDay.clamp(1, lastDayThisMonth));
    if (candidate.isBefore(today)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final lastDayNext =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      candidate = DateTime(
        nextMonth.year,
        nextMonth.month,
        dueDay.clamp(1, lastDayNext),
      );
    }
    return candidate;
  }

  DateTime _nextSpecialDayDate(SpecialDay day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDayThisYear = DateTime(now.year, day.month + 1, 0).day;
    var candidate =
        DateTime(now.year, day.month, day.day.clamp(1, lastDayThisYear));
    if (candidate.isBefore(today)) {
      final lastDayNextYear = DateTime(now.year + 1, day.month + 1, 0).day;
      candidate = DateTime(
          now.year + 1, day.month, day.day.clamp(1, lastDayNextYear));
    }
    return candidate;
  }

  Future<void> _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    double currentLimit,
  ) async {
    final ctrl = TextEditingController(text: currentLimit.toStringAsFixed(0));
    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Monthly Budget Limit'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(budgetProvider);
    final calendar = ref.watch(calendarProvider);
    final tasksState = ref.watch(tasksProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final formattedDate = DateFormat('EEEE, MMM d').format(now);

    final ratio = budget.monthlyBudgetLimit <= 0
        ? 0.0
        : (budget.totalSpentThisMonth / budget.monthlyBudgetLimit)
            .clamp(0.0, 1.0);
    final progressColor = ratio < 0.75
        ? AppColors.emerald
        : (ratio <= 0.95 ? AppColors.amber : AppColors.red);

    // Smart Upcoming Alerts within next 14 days
    final alerts = <({
      DateTime date,
      int daysAway,
      bool isBill,
      RecurringBill? bill,
      SpecialDay? specialDay,
    })>[];

    for (final bill in budget.recurringBills) {
      if (budget.isBillPaidForCurrentMonth(bill)) continue;
      final d = _nextBillDate(bill.dueDay);
      final diff = d.difference(today).inDays;
      if (diff >= 0 && diff <= 14) {
        alerts.add((
          date: d,
          daysAway: diff,
          isBill: true,
          bill: bill,
          specialDay: null,
        ));
      }
    }

    for (final sday in calendar.specialDays) {
      final d = _nextSpecialDayDate(sday);
      final diff = d.difference(today).inDays;
      if (diff >= 0 && diff <= 14) {
        alerts.add((
          date: d,
          daysAway: diff,
          isBill: false,
          bill: null,
          specialDay: sday,
        ));
      }
    }
    alerts.sort((a, b) => a.daysAway.compareTo(b.daysAway));

    // Today's Tasks Preview (incomplete tasks due today or high priority, up to 4)
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final previewTasks = tasksState.tasks
        .where((t) =>
            !t.isCompleted &&
            (t.priority == 3 ||
                t.dueDate == null ||
                !t.dueDate!.isAfter(todayEnd)))
        .take(4)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Quick-Add
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Settings & Info',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardElevated,
                      foregroundColor: AppColors.emerald,
                    ),
                    onPressed: () => showQuickAddSheet(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly Financial Snapshot Card
          InkWell(
            onTap: () =>
                _showEditBudgetDialog(context, ref, budget.monthlyBudgetLimit),
            borderRadius: BorderRadius.circular(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining Budget',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: progressColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${(ratio * 100).round()}% Spent',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: progressColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrency(budget.remainingBudget),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Spent: ${formatCurrency(budget.totalSpentThisMonth)} / ${formatCurrency(budget.monthlyBudgetLimit, showDecimals: false)} • Income: +${formatCurrency(budget.totalIncomeThisMonth, showDecimals: false)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0, end: ratio),
                        builder: (_, val, _) => LinearProgressIndicator(
                          value: val,
                          minHeight: 10,
                          backgroundColor: AppColors.inputBg,
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Smart Upcoming Alerts Carousel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Alerts (14 Days)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${alerts.length} active',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: AppColors.emerald),
                    SizedBox(width: 12),
                    Text(
                      'All clear for the next 2 weeks',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: alerts.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, idx) {
                  final item = alerts[idx];
                  if (item.isBill && item.bill != null) {
                    final bill = item.bill!;
                    final isToday = item.daysAway == 0;
                    final badgeColor = isToday ? AppColors.red : AppColors.amber;
                    final badgeText = isToday
                        ? 'Due Today'
                        : 'Due in ${item.daysAway} day${item.daysAway == 1 ? "" : "s"}';
                    return Container(
                      width: 224,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.emerald,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () =>
                                    confirmAndMarkBillPaid(context, ref, bill),
                                child: const Text(
                                  'Pay',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bill.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${bill.isVariable ? "~" : ""}${formatCurrency(bill.amount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final sday = item.specialDay!;
                  final label = item.daysAway == 0
                      ? '🎂 Today: ${sday.title}'
                      : item.daysAway == 1
                          ? '🎂 Tomorrow: ${sday.title}'
                          : 'In ${item.daysAway} days';
                  return Container(
                    width: 224,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.electricBlue.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.electricBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sday.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMMM d').format(item.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),

          // Today's Tasks Preview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Tasks",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(shellTabProvider.notifier).setTab(3),
                        child: const Text('View All →'),
                      ),
                    ],
                  ),
                  if (previewTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No pending tasks for today. Tap + to add one.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...previewTasks.map(
                      (task) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: InkWell(
                          onTap: () => ref
                              .read(tasksProvider.notifier)
                              .toggleTask(task),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: task.priority == 3
                                    ? AppColors.red
                                    : AppColors.electricBlue,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          task.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: task.priority == 3
                            ? const Icon(
                                Icons.flag_rounded,
                                color: AppColors.red,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
