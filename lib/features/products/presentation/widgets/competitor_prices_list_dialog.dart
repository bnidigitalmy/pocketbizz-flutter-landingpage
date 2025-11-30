import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/competitor_price.dart';
import '../../../../data/models/product.dart';
import '../../../../data/repositories/competitor_prices_repository_supabase.dart';
import 'competitor_price_dialog.dart';

/// Dialog to list and manage competitor prices
class CompetitorPricesListDialog extends StatefulWidget {
  final Product product;
  final List<CompetitorPrice> competitorPrices;

  const CompetitorPricesListDialog({
    super.key,
    required this.product,
    required this.competitorPrices,
  });

  @override
  State<CompetitorPricesListDialog> createState() => _CompetitorPricesListDialogState();
}

class _CompetitorPricesListDialogState extends State<CompetitorPricesListDialog> {
  final _repo = CompetitorPricesRepositorySupabase();
  late List<CompetitorPrice> _prices;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prices = List.from(widget.competitorPrices);
  }

  Future<void> _refreshPrices() async {
    setState(() => _loading = true);
    try {
      final prices = await _repo.getCompetitorPrices(widget.product.id);
      if (mounted) {
        setState(() {
          _prices = prices;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editPrice(CompetitorPrice price) async {
    final result = await showDialog<CompetitorPrice>(
      context: context,
      builder: (context) => CompetitorPriceDialog(
        competitorPrice: price,
        productId: widget.product.id,
      ),
    );

    if (result != null) {
      try {
        setState(() => _loading = true);
        await _repo.updateCompetitorPrice(result);
        await _refreshPrices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Harga pesaing telah dikemaskini'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deletePrice(CompetitorPrice price) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Harga Pesaing'),
        content: Text('Adakah anda pasti mahu memadam harga dari "${price.competitorName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _loading = true);
        await _repo.deleteCompetitorPrice(price.id);
        await _refreshPrices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Harga pesaing telah dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getSourceLabel(String? source) {
    switch (source) {
      case 'physical_store':
        return 'Kedai Fizikal';
      case 'online_platform':
        return 'Platform Online';
      case 'marketplace':
        return 'Marketplace';
      case 'other':
        return 'Lain-lain';
      default:
        return 'Tidak dinyatakan';
    }
  }

  IconData _getSourceIcon(String? source) {
    switch (source) {
      case 'physical_store':
        return Icons.store;
      case 'online_platform':
        return Icons.shopping_cart;
      case 'marketplace':
        return Icons.public;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Harga Pesaing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _prices.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refreshPrices,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _prices.length,
                            itemBuilder: (context, index) {
                              final price = _prices[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Icon(
                                      _getSourceIcon(price.source),
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    price.competitorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RM${price.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            _getSourceIcon(price.source),
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getSourceLabel(price.source),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (price.lastUpdated != null) ...[
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd/MM/yyyy', 'ms').format(price.lastUpdated!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (price.notes != null && price.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          price.notes!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Padam', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editPrice(price);
                                      } else if (value == 'delete') {
                                        _deletePrice(price);
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<CompetitorPrice>(
                        context: context,
                        builder: (context) => CompetitorPriceDialog(
                          productId: widget.product.id,
                        ),
                      );

                      if (result != null) {
                        try {
                          setState(() => _loading = true);
                          await _repo.addCompetitorPrice(
                            productId: widget.product.id,
                            competitorName: result.competitorName,
                            price: result.price,
                            source: result.source,
                            lastUpdated: result.lastUpdated,
                            notes: result.notes,
                          );
                          await _refreshPrices();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Harga pesaing telah ditambah'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ralat: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Harga'),
                  ),
                ],
              ),
            ),
          ],
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
            Icons.price_check,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tiada harga pesaing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambah harga pesaing untuk analisis pasaran',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

