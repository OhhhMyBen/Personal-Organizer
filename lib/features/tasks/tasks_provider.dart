import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/models/models.dart';

enum TaskFilterMode { all, today, upcoming, completed }

class TasksState {
  const TasksState({
    required this.tasks,
    this.filter = TaskFilterMode.all,
    this.isLoading = false,
  });

  final List<TaskModel> tasks;
  final TaskFilterMode filter;
  final bool isLoading;

  int get totalCount => tasks.length;
  int get completedCount => tasks.where((t) => t.isCompleted).length;

  List<TaskModel> get filteredTasks {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return tasks.where((t) {
      return switch (filter) {
        TaskFilterMode.all => true,
        TaskFilterMode.today => !t.isCompleted &&
            (t.dueDate == null || !t.dueDate!.isAfter(todayEnd)),
        TaskFilterMode.upcoming =>
            !t.isCompleted && t.dueDate != null && t.dueDate!.isAfter(todayEnd),
        TaskFilterMode.completed => t.isCompleted,
      };
    }).toList();
  }

  TasksState copyWith({
    List<TaskModel>? tasks,
    TaskFilterMode? filter,
    bool? isLoading,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TasksNotifier extends Notifier<TasksState> {
  @override
  TasksState build() {
    Future.microtask(load);
    return const TasksState(tasks: [], isLoading: true);
  }

  Future<void> load() async {
    final tasks = await AppDatabase.instance.getTasks();
    state = state.copyWith(tasks: tasks, isLoading: false);
  }

  void setFilter(TaskFilterMode mode) {
    state = state.copyWith(filter: mode);
  }

  Future<void> addTask({
    required String title,
    DateTime? dueDate,
    int priority = 2,
    String category = 'Personal',
  }) async {
    final task = TaskModel(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      dueDate: dueDate,
      priority: priority,
      category: category,
      isCompleted: false,
    );
    await AppDatabase.instance.upsertTask(task);
    await load();
  }

  Future<void> updateTask(TaskModel task) async {
    await AppDatabase.instance.upsertTask(task);
    await load();
  }

  Future<void> toggleTask(TaskModel task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await AppDatabase.instance.upsertTask(updated);
    await load();
  }

  Future<void> deleteTask(String id) async {
    await AppDatabase.instance.deleteTask(id);
    await load();
  }

  Future<void> restoreTask(TaskModel task) async {
    await AppDatabase.instance.upsertTask(task);
    await load();
  }
}

final tasksProvider =
    NotifierProvider<TasksNotifier, TasksState>(TasksNotifier.new);
