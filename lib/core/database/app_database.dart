import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_organizer.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS incomes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL,
          notes TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE special_days ADD COLUMN recurrence TEXT NOT NULL DEFAULT 'yearly'",
      );
    }
    if (oldVersion < 4) {
      await db.delete(
        'recurring_bills',
        where: 'id IN (?, ?)',
        whereArgs: ['seed_atome_gas', 'seed_pldt_fiber'],
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recurring_bills (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        is_variable INTEGER NOT NULL DEFAULT 0,
        due_day INTEGER NOT NULL,
        category TEXT NOT NULL,
        last_paid_month TEXT,
        notify_days_before INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        linked_bill_id TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE special_days (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        year INTEGER,
        notify_day_before INTEGER NOT NULL DEFAULT 1,
        recurrence TEXT NOT NULL DEFAULT 'yearly'
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        due_date TEXT,
        priority INTEGER NOT NULL DEFAULT 2,
        category TEXT NOT NULL DEFAULT 'Personal',
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE incomes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('recurring_bills');
    await db.delete('expenses');
    await db.delete('special_days');
    await db.delete('tasks');
    await db.delete('incomes');
  }

  // --- Recurring Bills ---
  Future<List<RecurringBill>> getRecurringBills() async {
    final db = await database;
    final rows = await db.query('recurring_bills', orderBy: 'due_day ASC');
    return rows.map(RecurringBill.fromMap).toList();
  }

  Future<void> upsertRecurringBill(RecurringBill bill) async {
    final db = await database;
    await db.insert(
      'recurring_bills',
      bill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecurringBill(String id) async {
    final db = await database;
    await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
  }

  // --- Expenses ---
  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // --- Incomes ---
  Future<List<Income>> getIncomes() async {
    final db = await database;
    final rows = await db.query('incomes', orderBy: 'date DESC');
    return rows.map(Income.fromMap).toList();
  }

  Future<void> insertIncome(Income income) async {
    final db = await database;
    await db.insert(
      'incomes',
      income.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteIncome(String id) async {
    final db = await database;
    await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Special Days ---
  Future<List<SpecialDay>> getSpecialDays() async {
    final db = await database;
    final rows = await db.query('special_days', orderBy: 'month ASC, day ASC');
    return rows.map(SpecialDay.fromMap).toList();
  }

  Future<void> upsertSpecialDay(SpecialDay day) async {
    final db = await database;
    await db.insert(
      'special_days',
      day.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSpecialDay(String id) async {
    final db = await database;
    await db.delete('special_days', where: 'id = ?', whereArgs: [id]);
  }

  // --- Tasks ---
  Future<List<TaskModel>> getTasks() async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      orderBy: 'is_completed ASC, priority DESC, due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<void> upsertTask(TaskModel task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
