import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/app_database.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';

class BudgetState {
  const BudgetState({
    required this.monthlyBudgetLimit,
    required this.recurringBills,
    required this.expenses,
    required this.incomes,
    this.isLoading = false,
  });

  final double monthlyBudgetLimit;
  final List<RecurringBill> recurringBills;
  final List<Expense> expenses;
  final List<Income> incomes;
  final bool isLoading;

  String get currentYearMonth => DateFormat('yyyy-MM').format(DateTime.now());

  List<Expense> get currentMonthExpenses {
    final now = DateTime.now();
    return expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }

  List<Income> get currentMonthIncomes {
    final now = DateTime.now();
    return incomes
        .where((i) => i.date.year == now.year && i.date.month == now.month)
        .toList();
  }

  double get totalSpentThisMonth =>
      currentMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get totalIncomeThisMonth =>
      currentMonthIncomes.fold(0.0, (sum, i) => sum + i.amount);

  double get remainingBudget =>
      (monthlyBudgetLimit + totalIncomeThisMonth) - totalSpentThisMonth;

  double get netCashFlow => totalIncomeThisMonth - totalSpentThisMonth;

  double get upcomingBillsTotal => recurringBills
      .where((b) => !b.isPaidForMonth())
      .fold(0.0, (sum, b) => sum + b.amount);

  double get averageDailySpend {
    final dayOfMonth = DateTime.now().day.clamp(1, 31);
    return totalSpentThisMonth / dayOfMonth;
  }

  /// Returns a 7-day list of `(DateTime day, double totalSpent)` ending today.
  List<({DateTime day, double total})> get last7DaysSpending {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) {
      final d = today.subtract(Duration(days: 6 - index));
      final sum = expenses
          .where((e) =>
              e.date.year == d.year &&
              e.date.month == d.month &&
              e.date.day == d.day)
          .fold(0.0, (acc, e) => acc + e.amount);
      return (day: d, total: sum);
    });
  }

  bool isBillPaidForCurrentMonth(RecurringBill bill) =>
      bill.lastPaidMonth == currentYearMonth;

  Map<String, double> get categoryBreakdown {
    final map = <String, double>{};
    for (final exp in currentMonthExpenses) {
      map[exp.category] = (map[exp.category] ?? 0.0) + exp.amount;
    }
    return map;
  }

  BudgetState copyWith({
    double? monthlyBudgetLimit,
    List<RecurringBill>? recurringBills,
    List<Expense>? expenses,
    List<Income>? incomes,
    bool? isLoading,
  }) {
    return BudgetState(
      monthlyBudgetLimit: monthlyBudgetLimit ?? this.monthlyBudgetLimit,
      recurringBills: recurringBills ?? this.recurringBills,
      expenses: expenses ?? this.expenses,
      incomes: incomes ?? this.incomes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BudgetNotifier extends Notifier<BudgetState> {
  static const _budgetLimitKey = 'monthly_budget_limit';

  @override
  BudgetState build() {
    Future.microtask(load);
    return const BudgetState(
      monthlyBudgetLimit: 20000.0,
      recurringBills: [],
      expenses: [],
      incomes: [],
      isLoading: true,
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final limit = prefs.getDouble(_budgetLimitKey) ?? 20000.0;
    final bills = await AppDatabase.instance.getRecurringBills();
    final expenses = await AppDatabase.instance.getExpenses();
    final incomes = await AppDatabase.instance.getIncomes();
    state = BudgetState(
      monthlyBudgetLimit: limit,
      recurringBills: bills,
      expenses: expenses,
      incomes: incomes,
      isLoading: false,
    );
  }

  Future<void> setMonthlyBudgetLimit(double limit) async {
    if (limit <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetLimitKey, limit);
    state = state.copyWith(monthlyBudgetLimit: limit);
  }

  Future<void> addRecurringBill({
    required String title,
    required double amount,
    required bool isVariable,
    required int dueDay,
    required String category,
    int notifyDaysBefore = 1,
  }) async {
    final bill = RecurringBill(
      id: 'bill_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      isVariable: isVariable,
      dueDay: dueDay,
      category: category,
      notifyDaysBefore: notifyDaysBefore,
      createdAt: DateTime.now(),
    );
    await AppDatabase.instance.upsertRecurringBill(bill);
    await NotificationService.instance.scheduleMonthlyBillReminder(bill);
    await load();
  }

  Future<void> updateBillAmount(RecurringBill bill, double newAmount) async {
    final updated = bill.copyWith(amount: newAmount);
    await AppDatabase.instance.upsertRecurringBill(updated);
    await load();
  }

  Future<void> markBillAsPaid(RecurringBill bill, double finalAmount) async {
    final ym = DateFormat('yyyy-MM').format(DateTime.now());
    final expense = Expense(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      title: bill.title,
      amount: finalAmount,
      category: bill.category,
      date: DateTime.now(),
      linkedBillId: bill.id,
      notes: 'Recurring bill payment ($ym)',
    );
    await AppDatabase.instance.insertExpense(expense);

    final updatedBill = bill.copyWith(
      amount: bill.isVariable ? finalAmount : bill.amount,
      lastPaidMonth: ym,
    );
    await AppDatabase.instance.upsertRecurringBill(updatedBill);
    await NotificationService.instance.scheduleMonthlyBillReminder(
      updatedBill,
      forceNextMonth: true,
    );
    await load();
  }

  Future<void> deleteRecurringBill(String id) async {
    await AppDatabase.instance.deleteRecurringBill(id);
    await NotificationService.instance.cancelBillNotifications(id);
    await load();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final expense = Expense(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      category: category,
      date: date,
      notes: notes,
    );
    await AppDatabase.instance.insertExpense(expense);
    await load();
  }

  Future<void> deleteExpense(String id) async {
    await AppDatabase.instance.deleteExpense(id);
    await load();
  }

  Future<void> addIncome({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final income = Income(
      id: 'inc_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      category: category,
      date: date,
      notes: notes,
    );
    await AppDatabase.instance.insertIncome(income);
    await load();
  }

  Future<void> deleteIncome(String id) async {
    await AppDatabase.instance.deleteIncome(id);
    await load();
  }
}

final budgetProvider =
    NotifierProvider<BudgetNotifier, BudgetState>(BudgetNotifier.new);
