import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import 'budget_provider.dart';

/// Shows a confirmation dialog before marking any recurring bill as paid.
/// Variable bills also allow adjusting the exact ₱ amount paid.
Future<void> confirmAndMarkBillPaid(
  BuildContext context,
  WidgetRef ref,
  RecurringBill bill,
) async {
  final ctrl = TextEditingController(text: bill.amount.toStringAsFixed(2));

  final confirmedAmount = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Confirm Payment',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bill.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${bill.category} • Due Day ${bill.dueDay}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (bill.isVariable)
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₱ ',
                labelText: 'Exact Amount Paid',
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Amount',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    formatCurrency(bill.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final parsed = bill.isVariable
                ? double.tryParse(ctrl.text.replaceAll(',', '').trim())
                : bill.amount;
            if (parsed != null && parsed > 0) {
              Navigator.pop(ctx, parsed);
            }
          },
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text(
            'Confirm Payment',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (confirmedAmount == null || confirmedAmount <= 0) return;

  await ref
      .read(budgetProvider.notifier)
      .markBillAsPaid(bill, confirmedAmount);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${bill.title} (${formatCurrency(confirmedAmount)}) confirmed & marked Paid ✓',
        ),
      ),
    );
  }
}
