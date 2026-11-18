import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'budget_provider.dart';

class BudgetAnalyticsView extends StatelessWidget {
  const BudgetAnalyticsView({super.key, required this.budget});

  final BudgetState budget;

  static const _palette = [
    AppColors.emerald,
    AppColors.electricBlue,
    AppColors.amber,
    AppColors.purple,
    AppColors.red,
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context) {
    final totalIncome = budget.totalIncomeThisMonth;
    final totalExpense = budget.totalSpentThisMonth;
    final net = budget.netCashFlow;
    final avgDaily = budget.averageDailySpend;

    final categoryEntries = budget.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final last7Days = budget.last7DaysSpending;
    final maxDaySpend = last7Days.fold<double>(
      1.0,
      (maxVal, e) => e.total > maxVal ? e.total : maxVal,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cash Flow 2x2 KPI Grid
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Income (Month)',
                value: '+${formatCurrency(totalIncome)}',
                color: AppColors.emerald,
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Expenses (Month)',
                value: '-${formatCurrency(totalExpense)}',
                color: AppColors.red,
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Net Cash Flow',
                value:
                    '${net >= 0 ? "+" : ""}${formatCurrency(net)}',
                color: net >= 0 ? AppColors.emerald : AppColors.red,
                icon: Icons.swap_vert_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Avg. Daily Spend',
                value: formatCurrency(avgDaily),
                color: AppColors.amber,
                icon: Icons.speed_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 7-Day Spending Bar Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7-Day Spending Trend',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 130,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: last7Days.map((item) {
                      final ratio =
                          (item.total / maxDaySpend).clamp(0.0, 1.0);
                      final barHeight = max(6.0, ratio * 88.0);
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (item.total > 0)
                              Text(
                                formatCurrency(item.total, showDecimals: false),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: item.total > 0
                                    ? AppColors.electricBlue
                                    : AppColors.cardElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('E').format(item.day),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Category Donut Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expense Breakdown by Category',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (categoryEntries.isEmpty || totalExpense <= 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Log expenses to visualize your spending categories.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            values:
                                categoryEntries.map((e) => e.value).toList(),
                            colors: _palette,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  formatCurrency(
                                    totalExpense,
                                    showDecimals: false,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: List.generate(categoryEntries.length, (i) {
                            final e = categoryEntries[i];
                            final pct =
                                ((e.value / totalExpense) * 100).round();
                            final color = _palette[i % _palette.length];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    var startAngle = -pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.03,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}
