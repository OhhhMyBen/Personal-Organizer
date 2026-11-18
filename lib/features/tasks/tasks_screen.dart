import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import 'tasks_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _quickController = TextEditingController();
  DateTime? _quickDueDate = DateTime.now();
  int _quickPriority = 2; // 1=Low, 2=Med, 3=High

  @override
  void dispose() {
    _quickController.dispose();
    super.dispose();
  }

  Future<void> _submitQuickTask() async {
    final title = _quickController.text.trim();
    if (title.isEmpty) return;
    await ref.read(tasksProvider.notifier).addTask(
          title: title,
          dueDate: _quickDueDate,
          priority: _quickPriority,
        );
    _quickController.clear();
  }

  Future<void> _showEditTaskSheet(TaskModel task) async {
    final titleCtrl = TextEditingController(text: task.title);
    int priority = task.priority;
    String category = task.category;
    DateTime? dueDate = task.dueDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  (1, 'Low', AppColors.textSecondary),
                  (2, 'Med', AppColors.amber),
                  (3, 'High', AppColors.red),
                ].map((p) {
                  final active = priority == p.$1;
                  return ChoiceChip(
                    label: Text(p.$2),
                    selected: active,
                    selectedColor: p.$3,
                    onSelected: (_) => setModalState(() => priority = p.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Personal', 'Finance', 'Work', 'Errands'].map((c) {
                  return ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    selectedColor: AppColors.electricBlue,
                    onSelected: (_) => setModalState(() => category = c),
                  );
                }).toList(),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date'),
                subtitle: Text(
                  dueDate == null
                      ? 'No due date'
                      : DateFormat('MMM d, yyyy').format(dueDate!),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setModalState(() => dueDate = picked);
                  },
                  child: const Text('Pick'),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricBlue,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final updatedTitle = titleCtrl.text.trim();
                  if (updatedTitle.isNotEmpty) {
                    await ref.read(tasksProvider.notifier).updateTask(
                          task.copyWith(
                            title: updatedTitle,
                            priority: priority,
                            category: category,
                            dueDate: dueDate,
                          ),
                        );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final total = tasksState.totalCount;
    final completed = tasksState.completedCount;
    final ratio = total == 0 ? 0.0 : completed / total;
    final items = tasksState.filteredTasks;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Header + Progress
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$completed / $total Done',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: AppColors.cardBg,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.electricBlue),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(TaskFilterMode.all, 'All', tasksState.filter),
                    const SizedBox(width: 8),
                    _filterChip(
                        TaskFilterMode.today, 'Today', tasksState.filter),
                    const SizedBox(width: 8),
                    _filterChip(
                        TaskFilterMode.upcoming, 'Upcoming', tasksState.filter),
                    const SizedBox(width: 8),
                    _filterChip(TaskFilterMode.completed, 'Completed',
                        tasksState.filter),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Task List
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks in this view.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final task = items[idx];
                    final (pLabel, pColor) = switch (task.priority) {
                      3 => ('High', AppColors.red),
                      2 => ('Med', AppColors.amber),
                      _ => ('Low', AppColors.textSecondary),
                    };

                    String dueText = 'No date';
                    Color dueColor = AppColors.textSecondary;
                    if (task.dueDate != null) {
                      final d = DateTime(
                        task.dueDate!.year,
                        task.dueDate!.month,
                        task.dueDate!.day,
                      );
                      if (d.isBefore(todayStart) && !task.isCompleted) {
                        dueText = 'Overdue • ${DateFormat('MMM d').format(d)}';
                        dueColor = AppColors.red;
                      } else if (d == todayStart) {
                        dueText = 'Today';
                        dueColor = AppColors.electricBlue;
                      } else {
                        dueText = DateFormat('MMM d').format(d);
                      }
                    }

                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) {
                        ref.read(tasksProvider.notifier).deleteTask(task.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${task.title}"'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => ref
                                  .read(tasksProvider.notifier)
                                  .restoreTask(task),
                            ),
                          ),
                        );
                      },
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
                          onTap: () => _showEditTaskSheet(task),
                          leading: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(tasksProvider.notifier).toggleTask(task);
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: task.isCompleted
                                    ? AppColors.electricBlue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: task.isCompleted
                                      ? AppColors.electricBlue
                                      : AppColors.textSecondary,
                                  width: 2,
                                ),
                              ),
                              child: task.isCompleted
                                  ? const Icon(Icons.check_rounded,
                                      size: 16, color: Colors.black)
                                  : null,
                            ),
                          ),
                          title: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: task.isCompleted
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            child: Text(task.title),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  dueText,
                                  style:
                                      TextStyle(fontSize: 11, color: dueColor),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: pColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              pLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Docked Quick-Add Task Bar
        Padding(
          padding: EdgeInsets.only(
            bottom: (MediaQuery.viewInsetsOf(context).bottom - 80)
                .clamp(0.0, double.infinity),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: AppColors.cardBg,
            child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickController,
                  onSubmitted: (_) => _submitQuickTask(),
                  decoration: InputDecoration(
                    hintText: 'Add a task...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Due Date',
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _quickDueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  setState(() => _quickDueDate = picked);
                },
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: _quickDueDate != null
                      ? AppColors.electricBlue
                      : AppColors.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Cycle Priority',
                onPressed: () {
                  setState(() {
                    _quickPriority = (_quickPriority % 3) + 1;
                  });
                },
                icon: Icon(
                  Icons.flag_rounded,
                  color: switch (_quickPriority) {
                    3 => AppColors.red,
                    2 => AppColors.amber,
                    _ => AppColors.textSecondary,
                  },
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.electricBlue,
                  foregroundColor: Colors.black,
                ),
                onPressed: _submitQuickTask,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _filterChip(
    TaskFilterMode mode,
    String label,
    TaskFilterMode current,
  ) {
    final active = mode == current;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: AppColors.electricBlue,
      backgroundColor: AppColors.cardBg,
      labelStyle: TextStyle(
        color: active ? Colors.black : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (_) => ref.read(tasksProvider.notifier).setFilter(mode),
    );
  }
}
