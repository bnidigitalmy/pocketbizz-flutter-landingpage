import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/sales_repository_supabase.dart';

/// Sales Page - Enhanced UI with summary cards and channel filters
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _repo = SalesRepositorySupabase();
  List<Sale> _sales = [];
  bool _loading = false;
  String? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _loading = true);

    try {
      final sales = await _repo.listSales(channel: _selectedChannel);
      if (mounted) {
        setState(() {
          _sales = sales;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat jualan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _totalSales => _sales.fold(0.0, (sum, s) => sum + s.finalAmount);

  double get _todaySales {
    final today = DateTime.now();
    return _sales
        .where((s) => DateUtils.isSameDay(s.createdAt, today))
        .fold(0.0, (sum, s) => sum + s.finalAmount);
  }

  int get _todayCount {
    final today = DateTime.now();
    return _sales.where((s) => DateUtils.isSameDay(s.createdAt, today)).length;
  }

  Map<String, double> get _channelTotals {
    final totals = <String, double>{};
    for (final sale in _sales) {
      totals[sale.channel] = (totals[sale.channel] ?? 0) + sale.finalAmount;
    }
    return totals;
  }

  List<Sale> get _filteredSales {
    if (_selectedChannel == null) return _sales;
    return _sales.where((s) => s.channel == _selectedChannel).toList();
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(canPop),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSales,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSummary(),
                    const SizedBox(height: 12),
                    _buildChannelFilters(),
                    const SizedBox(height: 12),
                    _buildSalesList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).pushNamed('/sales/create');
          if (result == true && mounted) {
            _loadSales();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jualan'),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool canPop) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (canPop) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jualan'),
          Text(
            'Rekod semua transaksi jualan',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildHeaderSummary() {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jumlah Jualan',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_totalSales),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hari Ini',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(_todaySales),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    '$_todayCount transaksi',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelFilters() {
    final channels = [
      {'key': null, 'label': 'Semua', 'icon': Icons.all_inclusive},
      {'key': 'walk-in', 'label': 'Walk-in', 'icon': Icons.store},
      {'key': 'online', 'label': 'Online', 'icon': Icons.shopping_cart},
      {'key': 'delivery', 'label': 'Delivery', 'icon': Icons.local_shipping},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Ringkasan mengikut saluran',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Tap kad untuk tapis.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: channels.map((ch) {
              final key = ch['key'] as String?;
              final isSelected = _selectedChannel == key;
              final amount = key == null
                  ? _totalSales
                  : _channelTotals[key] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedChannel = isSelected ? null : key;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryDark
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              ch['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ch['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(amount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesList() {
    final filtered = _filteredSales;
    
    if (filtered.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.point_of_sale,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tiada jualan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedChannel == null
                    ? 'Mulakan dengan merekod jualan pertama anda.'
                    : 'Tiada jualan untuk saluran ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((sale) {
        final isToday = DateUtils.isSameDay(sale.createdAt, DateTime.now());
        final channelColor = _getChannelColor(sale.channel);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showSaleDetails(sale),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: channelColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getChannelIcon(sale.channel),
                      color: channelColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: channelColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getChannelLabel(sale.channel),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: channelColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateTime(sale.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Hari ini',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sale.customerName ?? 'Pelanggan Tanpa Nama',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (sale.items != null && sale.items!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${sale.items!.length} item${sale.items!.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(sale.finalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getChannelColor(String channel) {
    switch (channel) {
      case 'walk-in':
        return AppColors.info;
      case 'online':
        return AppColors.primary;
      case 'delivery':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel) {
      case 'walk-in':
        return Icons.store;
      case 'online':
        return Icons.shopping_cart;
      case 'delivery':
        return Icons.local_shipping;
      default:
        return Icons.point_of_sale;
    }
  }

  String _getChannelLabel(String channel) {
    switch (channel) {
      case 'walk-in':
        return 'Walk-in';
      case 'online':
        return 'Online';
      case 'delivery':
        return 'Delivery';
      default:
        return channel.toUpperCase();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Hari ini ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm', 'ms_MY').format(dateTime);
    }
  }

  Future<void> _showSaleDetails(Sale sale) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getChannelColor(sale.channel)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getChannelIcon(sale.channel),
                              color: _getChannelColor(sale.channel),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jualan #${sale.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _getChannelLabel(sale.channel),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _getChannelColor(sale.channel),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Pelanggan',
                        sale.customerName ?? 'Pelanggan Tanpa Nama',
                      ),
                      _buildDetailRow('Tarikh', _formatDateTime(sale.createdAt)),
                      if (sale.notes != null && sale.notes!.isNotEmpty)
                        _buildDetailRow('Nota', sale.notes!),
                      const Divider(height: 24),
                      _buildDetailRow(
                        'Jumlah Awal',
                        _formatCurrency(sale.totalAmount),
                      ),
                      if (sale.discountAmount != null && sale.discountAmount! > 0)
                        _buildDetailRow(
                          'Diskaun',
                          '-${_formatCurrency(sale.discountAmount!)}',
                          valueColor: AppColors.error,
                        ),
                      _buildDetailRow(
                        'Jumlah Akhir',
                        _formatCurrency(sale.finalAmount),
                        bold: true,
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: 16),
                      if (sale.items != null && sale.items!.isNotEmpty) ...[
                        const Text(
                          'Item:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: sale.items!.length,
                            itemBuilder: (context, index) {
                              final item = sale.items![index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Colors.grey[200]!,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Kuantiti: ${item.quantity} × ${_formatCurrency(item.unitPrice)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(
                                    _formatCurrency(item.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Tutup'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Print receipt
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cetak resit - Akan datang!'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cetak'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
