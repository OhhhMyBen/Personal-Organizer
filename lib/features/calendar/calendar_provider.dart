import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';

class CalendarState {
  const CalendarState({
    required this.specialDays,
    required this.focusedMonth,
    required this.selectedDate,
    this.isLoading = false,
  });

  final List<SpecialDay> specialDays;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final bool isLoading;

  CalendarState copyWith({
    List<SpecialDay>? specialDays,
    DateTime? focusedMonth,
    DateTime? selectedDate,
    bool? isLoading,
  }) {
    return CalendarState(
      specialDays: specialDays ?? this.specialDays,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final now = DateTime.now();
    Future.microtask(load);
    return CalendarState(
      specialDays: const [],
      focusedMonth: DateTime(now.year, now.month, 1),
      selectedDate: DateTime(now.year, now.month, now.day),
      isLoading: true,
    );
  }

  Future<void> load() async {
    final days = await AppDatabase.instance.getSpecialDays();
    state = state.copyWith(specialDays: days, isLoading: false);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
    );
  }

  void changeMonth(int delta) {
    final next = DateTime(
      state.focusedMonth.year,
      state.focusedMonth.month + delta,
      1,
    );
    state = state.copyWith(focusedMonth: next);
  }

  void jumpToToday() {
    final now = DateTime.now();
    state = state.copyWith(
      focusedMonth: DateTime(now.year, now.month, 1),
      selectedDate: DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> addSpecialDay({
    required String title,
    required String type,
    required int month,
    required int day,
    int? year,
    bool notifyDayBefore = true,
    String recurrence = 'yearly',
  }) async {
    final specialDay = SpecialDay(
      id: 'sday_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: type,
      month: month,
      day: day,
      year: year,
      notifyDayBefore: notifyDayBefore,
      recurrence: recurrence,
    );
    await AppDatabase.instance.upsertSpecialDay(specialDay);
    if (notifyDayBefore) {
      await NotificationService.instance.scheduleBirthdayReminder(specialDay);
    }
    await load();
  }

  Future<void> deleteSpecialDay(String id) async {
    await AppDatabase.instance.deleteSpecialDay(id);
    await NotificationService.instance.cancelNotification(
      NotificationService.instance.birthdayNotificationId(id),
    );
    await load();
  }
}

final calendarProvider =
    NotifierProvider<CalendarNotifier, CalendarState>(CalendarNotifier.new);
