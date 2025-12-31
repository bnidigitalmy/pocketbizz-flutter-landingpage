import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import 'sale_details_dialog.dart';
import 'create_sale_page_enhanced.dart';

/// Enhanced Sales Page
/// User-friendly, easy to navigate, and consistent UI/UX
class SalesPageEnhanced extends StatefulWidget {
  const SalesPageEnhanced({super.key});

  @override
  State<SalesPageEnhanced> createState() => _SalesPageEnhancedState();
}

class _SalesPageEnhancedState extends State<SalesPageEnhanced> {
  final _repo = SalesRepositorySupabase();
  List<Sale> _sales = [];
  List<Sale> _filteredSales = [];
  bool _loading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Filter states
  String? _selectedChannel;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  bool _showFilters = false;

  // Summary statistics
  double _todayTotal = 0.0;
  int _todayCount = 0;
  Map<String, double> _channelTotals = {};

  @override
  void initState() {
    super.initState();
    _loadSales();
    _loadTodaySummary();
  }

  Future<void> _loadSales({bool reset = false}) async {
    if (reset) {
      _sales = [];
    }

    setState(() => reset ? _loading = true : _isLoadingMore = true);

    try {
      final sales = await _repo.listSales(
        channel: _selectedChannel,
        startDate: _startDate,
        endDate: _endDate,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _sales = sales;
          } else {
            _sales.addAll(sales);
          }
          _hasMore = sales.length >= 50;
          _loading = false;
          _isLoadingMore = false;
        });
        _applySearchFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTodaySummary() async {
    try {
      final summary = await _repo.getTodaySummary();
      if (mounted) {
        setState(() {
          _todayTotal = (summary['total_sales'] as num).toDouble();
          _todayCount = summary['transaction_count'] as int;
        });
      }

      // Calculate channel totals
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySales = _sales.where((sale) {
        return sale.createdAt.isAfter(startOfDay) && sale.createdAt.isBefore(endOfDay);
      }).toList();

      final channelTotals = <String, double>{};
      for (final sale in todaySales) {
        channelTotals[sale.channel] = (channelTotals[sale.channel] ?? 0.0) + sale.finalAmount;
      }

      if (mounted) {
        setState(() => _channelTotals = channelTotals);
      }
    } catch (e) {
      debugPrint('Error loading today summary: $e');
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredSales = _sales;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredSales = _sales.where((sale) {
        final customerName = sale.customerName?.toLowerCase() ?? '';
        final notes = sale.notes?.toLowerCase() ?? '';
        final channel = sale.channel.toLowerCase();
        return customerName.contains(query) ||
            notes.contains(query) ||
            channel.contains(query);
      }).toList();
    }
  }

  Map<String, List<Sale>> _groupSalesByDate(List<Sale> sales) {
    final grouped = <String, List<Sale>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(Duration(days: now.weekday - 1));
    final thisMonth = DateTime(now.year, now.month, 1);

    for (final sale in sales) {
      final saleDate = DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day);
      String groupKey;

      if (saleDate == today) {
        groupKey = 'Hari Ini';
      } else if (saleDate == yesterday) {
        groupKey = 'Semalam';
      } else if (saleDate.isAfter(thisWeek.subtract(const Duration(days: 1)))) {
        groupKey = 'Minggu Ini';
      } else if (saleDate.isAfter(thisMonth.subtract(const Duration(days: 1)))) {
        groupKey = 'Bulan Ini';
      } else {
        groupKey = DateFormat('MMMM yyyy', 'ms').format(saleDate);
      }

      grouped.putIfAbsent(groupKey, () => []).add(sale);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedSales = _groupSalesByDate(_filteredSales);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jualan'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          if (!_loading && _sales.isNotEmpty) _buildSummaryCards(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari jualan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _applySearchFilter();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applySearchFilter();
              },
            ),
          ),

          // Filters
          if (_showFilters) _buildFilters(),

          // Sales List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSales.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadSales(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: groupedSales.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == groupedSales.length) {
                              if (_isLoadingMore) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            final groupKey = groupedSales.keys.elementAt(index);
                            final groupSales = groupedSales[groupKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    groupKey,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                ...groupSales.map((sale) => _buildSaleCard(sale)),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateSalePageEnhanced(),
            ),
          );
          if (result == true && mounted) {
            await _loadSales(reset: true);
            await _loadTodaySummary();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Jualan Baru'),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Hari Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Jumlah Jualan',
                  'RM${_todayTotal.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Bilangan Transaksi',
                  '$_todayCount',
                  Icons.receipt,
                  Colors.blue,
                ),
              ),
            ],
          ),
          if (_channelTotals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _channelTotals.entries.map((entry) {
                return Chip(
                  avatar: Icon(_getChannelIcon(entry.key), size: 18),
                  label: Text(
                    '${_getChannelLabel(entry.key)}: RM${entry.value.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getChannelColor(entry.key).withOpacity(0.1),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filter',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedChannel = null;
                    _startDate = null;
                    _endDate = null;
                  });
                  _loadSales(reset: true);
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Channel Filter
          DropdownButtonFormField<String>(
            value: _selectedChannel,
            decoration: const InputDecoration(
              labelText: 'Saluran Jualan',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua')),
              const DropdownMenuItem(value: 'walk-in', child: Text('Walk-in')),
              const DropdownMenuItem(value: 'online', child: Text('Online')),
              const DropdownMenuItem(value: 'delivery', child: Text('Penghantaran')),
            ],
            onChanged: (value) {
              setState(() => _selectedChannel = value);
              _loadSales(reset: true);
            },
          ),
          const SizedBox(height: 12),
          // Date Range
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                      _loadSales(reset: true);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dari Tarikh',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
                    ),
                    child: Text(
                      _startDate != null
                          ? DateFormat('dd/MM/yyyy').format(_startDate!)
                          : 'Pilih tarikh',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                      _loadSales(reset: true);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hingga Tarikh',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 20),
                    ),
                    child: Text(
                      _endDate != null
                          ? DateFormat('dd/MM/yyyy').format(_endDate!)
                          : 'Pilih tarikh',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showSaleDetails(sale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Channel Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getChannelColor(sale.channel).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getChannelColor(sale.channel),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getChannelIcon(sale.channel),
                          size: 16,
                          color: _getChannelColor(sale.channel),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getChannelLabel(sale.channel),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getChannelColor(sale.channel),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Amount
                  Text(
                    'RM${sale.finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Customer & Items
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sale.customerName ?? 'Pelanggan Tanpa Nama',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (sale.items != null && sale.items!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${sale.items!.length} item${sale.items!.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              // Date & Time
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(sale.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (sale.discountAmount != null && sale.discountAmount! > 0) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Diskaun: RM${sale.discountAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tiada jualan dijumpai'
                : 'Tiada jualan lagi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Cuba cari dengan kata kunci lain'
                : 'Mula dengan membuat jualan pertama anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = DateFormat('HH:mm').format(dateTime);

    if (date == today) {
      return 'Hari ini, $timeStr';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Semalam, $timeStr';
    } else {
      return DateFormat('dd/MM/yyyy, HH:mm', 'ms').format(dateTime);
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel) {
      case 'walk-in':
        return Icons.store;
      case 'online':
        return Icons.shopping_cart;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.receipt;
    }
  }

  String _getChannelLabel(String channel) {
    switch (channel) {
      case 'walk-in':
        return 'Walk-in';
      case 'online':
        return 'Online';
      case 'delivery':
        return 'Penghantaran';
      default:
        return channel.toUpperCase();
    }
  }

  Color _getChannelColor(String channel) {
    switch (channel) {
      case 'walk-in':
        return Colors.blue;
      case 'online':
        return Colors.purple;
      case 'delivery':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showSaleDetails(Sale sale) async {
    await showDialog(
      context: context,
      builder: (context) => SaleDetailsDialog(sale: sale),
    );
  }
}

