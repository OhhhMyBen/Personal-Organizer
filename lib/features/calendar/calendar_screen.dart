import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../budget/bill_payment_dialog.dart';
import '../budget/budget_provider.dart';
import '../shared/quick_add_sheet.dart';
import '../tasks/tasks_provider.dart';
import 'calendar_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _showAllBirthdays = false;

  int _clampedDay(int year, int month, int targetDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return targetDay.clamp(1, lastDay);
  }

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calendarProvider);
    final budget = ref.watch(budgetProvider);
    final tasksState = ref.watch(tasksProvider);

    final month = cal.focusedMonth;
    final selected = cal.selectedDate;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7;
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;

    // Filter items for selectedDate
    final dayBills = budget.recurringBills
        .where((b) =>
            _clampedDay(selected.year, selected.month, b.dueDay) ==
            selected.day)
        .toList();
    final daySpecials =
        cal.specialDays.where((s) => s.matchesDate(selected)).toList();
    final dayTasks = tasksState.tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.year == selected.year &&
            t.dueDate!.month == selected.month &&
            t.dueDate!.day == selected.day)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calendar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        ref.read(calendarProvider.notifier).jumpToToday(),
                    child: const Text('Today'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () => showQuickAddSheet(
                      context,
                      initialTab: QuickAddTab.birthday,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text(
                      'Add Special Day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Month Switcher
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () =>
                            ref.read(calendarProvider.notifier).changeMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.read(calendarProvider.notifier).changeMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totalCells,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (_, idx) {
                      if (idx < startOffset) return const SizedBox.shrink();
                      final day = idx - startOffset + 1;
                      if (day > daysInMonth) return const SizedBox.shrink();

                      final cellDate = DateTime(month.year, month.month, day);
                      final isSelected = cellDate.year == selected.year &&
                          cellDate.month == selected.month &&
                          cellDate.day == selected.day;

                      final hasBill = budget.recurringBills.any((b) =>
                          _clampedDay(month.year, month.month, b.dueDay) ==
                          day);
                      final hasSpecial =
                          cal.specialDays.any((s) => s.matchesDate(cellDate));
                      final hasTask = tasksState.tasks.any((t) =>
                          t.dueDate != null &&
                          t.dueDate!.year == month.year &&
                          t.dueDate!.month == month.month &&
                          t.dueDate!.day == day);

                      return InkWell(
                        onTap: () => ref
                            .read(calendarProvider.notifier)
                            .selectDate(cellDate),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          decoration: isSelected
                              ? const BoxDecoration(
                                  color: AppColors.electricBlue,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.black
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hasBill)
                                    _dot(isSelected
                                        ? Colors.black
                                        : AppColors.amber),
                                  if (hasSpecial)
                                    _dot(isSelected
                                        ? Colors.black
                                        : AppColors.purple),
                                  if (hasTask)
                                    _dot(isSelected
                                        ? Colors.black
                                        : AppColors.electricBlue),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(AppColors.amber, 'Bill Due'),
              _legendItem(AppColors.purple, 'Birthday / Special'),
              _legendItem(AppColors.electricBlue, 'Task'),
            ],
          ),
          const SizedBox(height: 18),

          // Selected Day Agenda
          Text(
            'Agenda • ${DateFormat('MMM d, yyyy').format(selected)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (dayBills.isEmpty && daySpecials.isEmpty && dayTasks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No bills, birthdays, or tasks on this date.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ...daySpecials.map((s) {
            final age = s.type == 'birthday' ? s.ageInYear(selected.year) : null;
            final recLabel = switch (s.recurrence) {
              'monthly' => 'Monthly',
              'weekly' => 'Weekly',
              'once' => 'One-time',
              _ => 'Yearly',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.cardElevated,
                    child: Icon(
                      s.type == 'birthday'
                          ? Icons.cake_rounded
                          : Icons.event_repeat_rounded,
                      color: AppColors.purple,
                    ),
                  ),
                  title: Text(
                    age != null ? '${s.title} (Turns $age)' : s.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '$recLabel${s.notifyDayBefore ? " • 1-Day Before Alert Active" : ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.emerald,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => ref
                        .read(calendarProvider.notifier)
                        .deleteSpecialDay(s.id),
                  ),
                ),
              ),
            );
          }),
          ...dayBills.map((b) {
            final paid = budget.isBillPaidForCurrentMonth(b);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.cardElevated,
                    child:
                        Icon(Icons.receipt_long_rounded, color: AppColors.amber),
                  ),
                  title: Text(
                    b.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${b.isVariable ? "Variable" : "Fixed"} • ${formatCurrency(b.amount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: paid
                      ? const Text(
                          'Paid ✓',
                          style: TextStyle(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : TextButton(
                          onPressed: () =>
                              confirmAndMarkBillPaid(context, ref, b),
                          child: const Text('Mark Paid'),
                        ),
                ),
              ),
            );
          }),
          ...dayTasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Checkbox(
                    value: t.isCompleted,
                    activeColor: AppColors.electricBlue,
                    onChanged: (_) =>
                        ref.read(tasksProvider.notifier).toggleTask(t),
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          t.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(t.category),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Collapsible Upcoming Birthdays List
          Card(
            child: ExpansionTile(
              initiallyExpanded: _showAllBirthdays,
              onExpansionChanged: (v) => setState(() => _showAllBirthdays = v),
              title: Text(
                'Upcoming Birthdays & Special Days (${cal.specialDays.length})',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              children: cal.specialDays.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No special days saved yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ]
                  : cal.specialDays
                      .map(
                        (s) => ListTile(
                          title: Text(s.title),
                          subtitle: Text(
                            '${DateFormat('MMMM').format(DateTime(2026, s.month))} ${s.day}'
                            '${s.year != null ? " (${s.year})" : ""}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.red),
                            onPressed: () => ref
                                .read(calendarProvider.notifier)
                                .deleteSpecialDay(s.id),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _legendItem(Color c, String label) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}
