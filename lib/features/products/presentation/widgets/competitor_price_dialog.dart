import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/competitor_price.dart';

/// Dialog for adding/editing competitor prices
class CompetitorPriceDialog extends StatefulWidget {
  final CompetitorPrice? competitorPrice;
  final String productId;

  const CompetitorPriceDialog({
    super.key,
    this.competitorPrice,
    required this.productId,
  });

  @override
  State<CompetitorPriceDialog> createState() => _CompetitorPriceDialogState();
}

class _CompetitorPriceDialogState extends State<CompetitorPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  String? _selectedSource;
  DateTime? _lastUpdated;

  final List<String> _sources = [
    'physical_store',
    'online_platform',
    'marketplace',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.competitorPrice?.competitorName ?? '',
    );
    _priceController = TextEditingController(
      text: widget.competitorPrice?.price.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.competitorPrice?.notes ?? '',
    );
    _selectedSource = widget.competitorPrice?.source;
    _lastUpdated = widget.competitorPrice?.lastUpdated ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
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
        return 'Pilih Sumber';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.competitorPrice != null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Harga Pesaing' : 'Tambah Harga Pesaing',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Pesaing *',
                  hintText: 'cth: Kedai A, Shopee, Lazada',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.store),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan nama pesaing';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Harga (RM) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan harga';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Harga mesti lebih daripada 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSource,
                decoration: InputDecoration(
                  labelText: 'Sumber Harga',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.source),
                ),
                items: _sources.map((source) {
                  return DropdownMenuItem(
                    value: source,
                    child: Text(_getSourceLabel(source)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSource = value);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _lastUpdated ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _lastUpdated = date);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tarikh Kemaskini',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _lastUpdated != null
                        ? DateFormat('dd/MM/yyyy', 'ms').format(_lastUpdated!)
                        : 'Pilih tarikh',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Nota (Pilihan)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final competitorPrice = CompetitorPrice(
                          id: widget.competitorPrice?.id ?? '',
                          productId: widget.productId,
                          businessOwnerId: '', // Will be set by repository
                          competitorName: _nameController.text.trim(),
                          price: double.parse(_priceController.text),
                          source: _selectedSource,
                          lastUpdated: _lastUpdated,
                          notes: _notesController.text.trim().isEmpty
                              ? null
                              : _notesController.text.trim(),
                          createdAt: widget.competitorPrice?.createdAt ?? DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        Navigator.pop(context, competitorPrice);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isEditing ? 'Kemaskini' : 'Tambah'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

