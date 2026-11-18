import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalorganizer/core/models/models.dart';
import 'package:personalorganizer/core/theme/app_theme.dart';
import 'package:personalorganizer/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches directly into 5-tab MainShell without login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PersonalOrganizerApp()));
    await tester.pump();

    // Home Dashboard
    expect(find.text('Remaining Budget'), findsOneWidget);

    // Switch across all 5 bottom navigation tabs
    await tester.tap(find.text('Budget'));
    await tester.pump();
    expect(find.text('Budget & Bills'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pump();
    expect(find.text('Add Special Day'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(find.text('Add a task...'), findsOneWidget);

    await tester.tap(find.text('Vault'));
    await tester.pump();
    expect(find.text('Account Vault'), findsOneWidget);
  });

  test('Currency formatting and model serialization work offline', () {
    expect(formatCurrency(1400), '₱1,400.00');
    expect(formatCurrency(20000, showDecimals: false), '₱20,000');

    final bill = RecurringBill(
      id: 'b1',
      title: 'Atome Bank (Gas)',
      amount: 1400.0,
      isVariable: true,
      dueDay: 5,
      category: 'Transportation / Gas',
      createdAt: DateTime(2026, 11, 18),
    );
    final roundTrip = RecurringBill.fromMap(bill.toMap());
    expect(roundTrip.title, 'Atome Bank (Gas)');
    expect(roundTrip.isVariable, isTrue);
    expect(roundTrip.dueDay, 5);
  });
}
