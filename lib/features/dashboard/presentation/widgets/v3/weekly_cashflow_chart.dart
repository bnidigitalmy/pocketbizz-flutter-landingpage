import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../core/theme/app_colors.dart';
import '../v2/dashboard_v2_format.dart';

/// Daily cashflow data for the chart
class DailyCashflow {
  final String dayLabel; // Mon, Tue, etc.
  final double inflow;
  final double expense;

  const DailyCashflow({
    required this.dayLabel,
    required this.inflow,
    required this.expense,
  });

  double get net => inflow - expense;
}

/// Weekly Cashflow Bar Chart
class WeeklyCashflowChart extends StatefulWidget {
  final List<DailyCashflow> data;
  final double height;

  const WeeklyCashflowChart({
    super.key,
    required this.data,
    this.height = 180,
  });

  @override
  State<WeeklyCashflowChart> createState() => _WeeklyCashflowChartState();
}

class _WeeklyCashflowChartState extends State<WeeklyCashflowChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _maxValue {
    double max = 0;
    for (final d in widget.data) {
      if (d.inflow > max) max = d.inflow;
      if (d.expense > max) max = d.expense;
    }
    return max == 0 ? 100 : max * 1.2; // Add 20% padding
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Tiada data',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Column(
            children: [
              // Legend
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Masuk', AppColors.success),
                    const SizedBox(width: 20),
                    _buildLegendItem('Keluar', Colors.red.shade400),
                  ],
                ),
              ),
              // Chart
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxValue,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.grey.shade800,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final data = widget.data[groupIndex];
                          final isInflow = rodIndex == 0;
                          return BarTooltipItem(
                            '${isInflow ? "Masuk" : "Keluar"}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: DashboardV2Format.currency(
                                  isInflow ? data.inflow : data.expense,
                                ),
                                style: TextStyle(
                                  color: isInflow ? AppColors.success : Colors.red.shade300,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      touchCallback: (event, response) {
                        setState(() {
                          if (response == null || response.spot == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = response.spot!.touchedBarGroupIndex;
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < widget.data.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  widget.data[index].dayLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _touchedIndex == index
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                                    fontWeight: _touchedIndex == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _maxValue / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(widget.data.length, (index) {
                      final data = widget.data[index];
                      final isTouched = _touchedIndex == index;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          // Inflow bar
                          BarChartRodData(
                            toY: data.inflow * _animation.value,
                            color: isTouched
                                ? AppColors.success
                                : AppColors.success.withOpacity(0.8),
                            width: 12,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: _maxValue,
                              color: Colors.grey.shade100,
                            ),
                          ),
                          // Expense bar
                          BarChartRodData(
                            toY: data.expense * _animation.value,
                            color: isTouched
                                ? Colors.red.shade400
                                : Colors.red.shade300,
                            width: 12,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: _maxValue,
                              color: Colors.grey.shade100,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 300),
                  swapAnimationCurve: Curves.easeInOut,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Mini sparkline chart for compact display
class MiniCashflowSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  final double width;

  const MiniCashflowSparkline({
    super.key,
    required this.values,
    this.color = AppColors.success,
    this.height = 30,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height, width: width);

    return SizedBox(
      height: height,
      width: width,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(values.length, (i) {
                return FlSpot(i.toDouble(), values[i]);
              }),
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.15),
              ),
            ),
          ],
          minY: values.reduce((a, b) => a < b ? a : b) * 0.8,
          maxY: values.reduce((a, b) => a > b ? a : b) * 1.2,
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
