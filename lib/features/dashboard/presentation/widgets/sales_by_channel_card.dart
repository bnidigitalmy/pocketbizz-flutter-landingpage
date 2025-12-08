import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../reports/data/models/sales_by_channel.dart';

/// Sales by Channel Card
/// Shows revenue breakdown by sales channel
class SalesByChannelCard extends StatelessWidget {
  final List<SalesByChannel> salesByChannel;
  final double totalRevenue;

  const SalesByChannelCard({
    super.key,
    required this.salesByChannel,
    required this.totalRevenue,
  });

  IconData _getChannelIcon(String channel) {
    switch (channel.toLowerCase()) {
      case 'walk-in':
      case 'walkin':
        return Icons.store;
      case 'booking':
      case 'tempahan':
        return Icons.event_available;
      case 'myshop':
      case 'online':
        return Icons.shopping_cart;
      case 'consignment':
      case 'vendor':
        return Icons.business;
      case 'wholesale':
        return Icons.inventory_2;
      default:
        return Icons.point_of_sale;
    }
  }

  Color _getChannelColor(String channel) {
    switch (channel.toLowerCase()) {
      case 'walk-in':
      case 'walkin':
        return AppColors.primary;
      case 'booking':
      case 'tempahan':
        return Colors.orange;
      case 'myshop':
      case 'online':
        return Colors.blue;
      case 'consignment':
      case 'vendor':
        return Colors.purple;
      case 'wholesale':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (salesByChannel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Jualan Mengikut Saluran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${NumberFormat('#,##0.00').format(totalRevenue)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...salesByChannel.map((channel) {
              final icon = _getChannelIcon(channel.channel);
              final color = _getChannelColor(channel.channel);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.channelLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: channel.percentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${channel.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RM ${NumberFormat('#,##0.00').format(channel.revenue)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${channel.transactionCount} transaksi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

