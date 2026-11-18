import 'package:intl/intl.dart';

class RecurringBill {
  const RecurringBill({
    required this.id,
    required this.title,
    required this.amount,
    required this.isVariable,
    required this.dueDay,
    required this.category,
    this.lastPaidMonth,
    this.notifyDaysBefore = 1,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final bool isVariable;
  final int dueDay;
  final String category;
  final String? lastPaidMonth; // YYYY-MM
  final int notifyDaysBefore;
  final DateTime createdAt;

  bool isPaidForMonth([DateTime? ref]) {
    final now = ref ?? DateTime.now();
    final ym = DateFormat('yyyy-MM').format(now);
    return lastPaidMonth == ym;
  }

  RecurringBill copyWith({
    String? title,
    double? amount,
    bool? isVariable,
    int? dueDay,
    String? category,
    String? lastPaidMonth,
    int? notifyDaysBefore,
  }) {
    return RecurringBill(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      isVariable: isVariable ?? this.isVariable,
      dueDay: dueDay ?? this.dueDay,
      category: category ?? this.category,
      lastPaidMonth: lastPaidMonth ?? this.lastPaidMonth,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'is_variable': isVariable ? 1 : 0,
        'due_day': dueDay,
        'category': category,
        'last_paid_month': lastPaidMonth,
        'notify_days_before': notifyDaysBefore,
        'created_at': createdAt.toIso8601String(),
      };

  factory RecurringBill.fromMap(Map<String, dynamic> map) => RecurringBill(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        isVariable: (map['is_variable'] as int) == 1,
        dueDay: map['due_day'] as int,
        category: map['category'] as String,
        lastPaidMonth: map['last_paid_month'] as String?,
        notifyDaysBefore: map['notify_days_before'] as int? ?? 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.linkedBillId,
    this.notes,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? linkedBillId;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'linked_bill_id': linkedBillId,
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        date: DateTime.parse(map['date'] as String),
        linkedBillId: map['linked_bill_id'] as String?,
        notes: map['notes'] as String?,
      );
}

class Income {
  const Income({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.notes,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory Income.fromMap(Map<String, dynamic> map) => Income(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        date: DateTime.parse(map['date'] as String),
        notes: map['notes'] as String?,
      );
}

class SpecialDay {
  const SpecialDay({
    required this.id,
    required this.title,
    required this.type, // 'birthday', 'anniversary', 'event'
    required this.month,
    required this.day,
    this.year,
    this.notifyDayBefore = true,
    this.recurrence = 'yearly', // 'yearly', 'monthly', 'weekly', 'once'
  });

  final String id;
  final String title;
  final String type;
  final int month;
  final int day;
  final int? year;
  final bool notifyDayBefore;
  final String recurrence;

  int? ageInYear(int targetYear) => year != null ? targetYear - year! : null;

  bool matchesDate(DateTime date) {
    final lastDay = DateTime(date.year, date.month + 1, 0).day;
    final clamped = day.clamp(1, lastDay);
    return switch (recurrence) {
      'monthly' => clamped == date.day,
      'weekly' => () {
          final anchor = DateTime(year ?? 2026, month, day);
          final target = DateTime(date.year, date.month, date.day);
          return !target.isBefore(anchor) && target.weekday == anchor.weekday;
        }(),
      'once' => (year ?? date.year) == date.year &&
          month == date.month &&
          day == date.day,
      _ => month == date.month && clamped == date.day,
    };
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'month': month,
        'day': day,
        'year': year,
        'notify_day_before': notifyDayBefore ? 1 : 0,
        'recurrence': recurrence,
      };

  factory SpecialDay.fromMap(Map<String, dynamic> map) => SpecialDay(
        id: map['id'] as String,
        title: map['title'] as String,
        type: map['type'] as String,
        month: map['month'] as int,
        day: map['day'] as int,
        year: map['year'] as int?,
        notifyDayBefore: (map['notify_day_before'] as int? ?? 1) == 1,
        recurrence: map['recurrence'] as String? ?? 'yearly',
      );
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    this.dueDate,
    this.priority = 2, // 1=Low, 2=Med, 3=High
    this.category = 'Personal',
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final int priority;
  final String category;
  final bool isCompleted;

  TaskModel copyWith({
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? priority,
    String? category,
    bool? isCompleted,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'category': category,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel(
        id: map['id'] as String,
        title: map['title'] as String,
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        priority: map['priority'] as int? ?? 2,
        category: map['category'] as String? ?? 'Personal',
        isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      );
}

class AccountEntry {
  const AccountEntry({
    required this.id,
    required this.category, // 'Gmail & Google', 'Gaming', 'Banking & Bills', 'Other'
    required this.serviceName,
    required this.emailOrUsername,
    required this.passwordOrPin,
    this.notes = '',
    required this.updatedAt,
  });

  final String id;
  final String category;
  final String serviceName;
  final String emailOrUsername;
  final String passwordOrPin;
  final String notes;
  final DateTime updatedAt;

  AccountEntry copyWith({
    String? category,
    String? serviceName,
    String? emailOrUsername,
    String? passwordOrPin,
    String? notes,
    DateTime? updatedAt,
  }) {
    return AccountEntry(
      id: id,
      category: category ?? this.category,
      serviceName: serviceName ?? this.serviceName,
      emailOrUsername: emailOrUsername ?? this.emailOrUsername,
      passwordOrPin: passwordOrPin ?? this.passwordOrPin,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'serviceName': serviceName,
        'emailOrUsername': emailOrUsername,
        'passwordOrPin': passwordOrPin,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AccountEntry.fromJson(Map<String, dynamic> json) => AccountEntry(
        id: json['id'] as String,
        category: json['category'] as String,
        serviceName: json['serviceName'] as String,
        emailOrUsername: json['emailOrUsername'] as String,
        passwordOrPin: json['passwordOrPin'] as String,
        notes: json['notes'] as String? ?? '',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
