import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../reports/data/models/sales_by_channel.dart';
import '../v2/dashboard_v2_format.dart';
import 'stagger_animation.dart';
import 'animated_counter.dart';

/// Tab Jualan (Sales) - Sales by channel and upcoming bookings
class TabJualanV3 extends StatelessWidget {
  final List<SalesByChannel> salesByChannel;
  final int todayBookingsCount;
  final double todayBookingsAmount;
  final int tomorrowBookingsCount;
  final double tomorrowBookingsAmount;
  final int weekBookingsCount;
  final double weekBookingsAmount;
  final VoidCallback onViewAllBookings;

  const TabJualanV3({
    super.key,
    required this.salesByChannel,
    this.todayBookingsCount = 0,
    this.todayBookingsAmount = 0,
    this.tomorrowBookingsCount = 0,
    this.tomorrowBookingsAmount = 0,
    this.weekBookingsCount = 0,
    this.weekBookingsAmount = 0,
    required this.onViewAllBookings,
  });

  double get _totalRevenue => salesByChannel.fold(0.0, (sum, c) => sum + c.revenue);

  @override
  Widget build(BuildContext context) {
    // Removed StaggeredColumn for better performance - instant render
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sales by Channel
        _buildSalesByChannel(),
        const SizedBox(height: 16),
        // Upcoming Bookings
        _buildUpcomingBookings(),
      ],
    );
  }

  Widget _buildSalesByChannel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Jualan Mengikut Saluran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Hari Ini',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (salesByChannel.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tiada jualan hari ini',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...salesByChannel.map((channel) => _buildChannelRow(channel)),

          if (salesByChannel.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jumlah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DashboardV2Format.currency(_totalRevenue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelRow(SalesByChannel channel) {
    final percentage = _totalRevenue > 0 ? (channel.revenue / _totalRevenue) * 100 : 0.0;
    final color = _getChannelColor(channel.channel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getChannelDisplayName(channel.channel),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DashboardV2Format.currency(channel.revenue),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Color _getChannelColor(String channel) {
    switch (channel.toLowerCase()) {
      case 'walk_in':
      case 'walk-in':
        return Colors.blue;
      case 'booking':
        return Colors.orange;
      case 'online':
        return Colors.purple;
      case 'delivery':
        return Colors.green;
      case 'consignment':
        return Colors.teal;
      case 'wholesale':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getChannelDisplayName(String channel) {
    switch (channel.toLowerCase()) {
      case 'walk_in':
      case 'walk-in':
        return 'Walk-in';
      case 'booking':
        return 'Tempahan';
      case 'online':
        return 'Online';
      case 'delivery':
        return 'Delivery';
      case 'consignment':
        return 'Konsainan';
      case 'wholesale':
        return 'Borong';
      default:
        return channel;
    }
  }

  Widget _buildUpcomingBookings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tempahan Akan Datang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Today
          _buildBookingRow(
            label: 'Hari Ini',
            count: todayBookingsCount,
            amount: todayBookingsAmount,
            color: Colors.red,
          ),
          const SizedBox(height: 10),

          // Tomorrow
          _buildBookingRow(
            label: 'Esok',
            count: tomorrowBookingsCount,
            amount: tomorrowBookingsAmount,
            color: Colors.orange,
          ),
          const SizedBox(height: 10),

          // This Week
          _buildBookingRow(
            label: 'Minggu Ini',
            count: weekBookingsCount,
            amount: weekBookingsAmount,
            color: Colors.blue,
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ScaleOnTap(
              onTap: () {
                HapticFeedback.lightImpact();
                onViewAllBookings();
              },
              child: TextButton.icon(
                onPressed: onViewAllBookings,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Lihat Semua Tempahan'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingRow({
    required String label,
    required int count,
    required double amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count tempahan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          DashboardV2Format.currency(amount),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
