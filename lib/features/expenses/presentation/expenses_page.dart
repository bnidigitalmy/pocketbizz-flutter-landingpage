import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/expenses_repository_supabase.dart';

/// Expenses Page - Friendly UX for busy non-technical users.
///
/// Mirrors the optimized React UX:
/// - Quick add dialog with minimal fields
/// - Category summary cards (tap to filter)
/// - Simple, readable list sorted by date
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _repo = ExpensesRepositorySupabase();

  bool _isLoading = true;
  bool _isSaving = false;
  List<Expense> _expenses = [];
  String _selectedCategory = 'all';

  // Form state for dialog
  final _formKey = GlobalKey<FormState>();
  String _formCategory = 'bahan';
  String _formAmount = '';
  String _formDescription = '';
  DateTime _formDate = DateTime.now();

  // Category labels (slug -> display name). Starts with defaults but can be
  // extended by the user and from existing data.
  final Map<String, String> _categoryLabels = {
    'bahan': 'Bahan Mentah',
    'minyak': 'Minyak & Petrol',
    'upah': 'Upah Pekerja',
    'plastik': 'Plastik & Pembungkusan',
    'lain': 'Lain-lain',
  };

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getExpenses();
      if (mounted) {
        setState(() {
          _expenses = data;
          // Ensure we know about any categories already stored in DB.
          for (final exp in data) {
            if (!_categoryLabels.containsKey(exp.category)) {
              _categoryLabels[exp.category] = _titleCase(exp.category);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat perbelanjaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, double> get _categoryTotals {
    final totals = <String, double>{};
    for (final exp in _expenses) {
      totals[exp.category] = (totals[exp.category] ?? 0) + exp.amount;
    }
    return totals;
  }

  double get _totalAll =>
      _expenses.fold(0.0, (sum, e) => sum + e.amount);

  List<Expense> get _filteredExpenses {
    final list = _expenses.toList()
      ..sort(
        (a, b) => b.expenseDate.compareTo(a.expenseDate),
      );
    if (_selectedCategory == 'all') return list;
    return list.where((e) => e.category == _selectedCategory).toList();
  }

  String _titleCase(String value) {
    final trimmed = value.replaceAll('_', ' ').trim();
    if (trimmed.isEmpty) return value;
    return trimmed
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    ).format(value);
  }

  Future<void> _openAddDialog() async {
    _formCategory = 'bahan';
    _formAmount = '';
    _formDescription = '';
    _formDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rekod Perbelanjaan Baru'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Isi maklumat ringkas sahaja. Yang lain sistem uruskan.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _formCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _formCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isSaving ? null : _openAddCategoryDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Tambah kategori baru',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (RM)',
                      border: OutlineInputBorder(),
                      prefixText: 'RM ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: _formAmount,
                    onChanged: (value) => _formAmount = value,
                    validator: (value) {
                      final v = double.tryParse(value ?? '');
                      if (v == null || v <= 0) {
                        return 'Masukkan jumlah yang sah';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Penerangan (optional)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _formDescription,
                    maxLines: 2,
                    onChanged: (value) => _formDescription = value,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Tarikh',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: DateFormat('yyyy-MM-dd').format(_formDate),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _formDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _formDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Simpan Perbelanjaan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final amount = double.parse(_formAmount);
      final expense = await _repo.createExpense(
        category: _formCategory,
        amount: amount,
        expenseDate: _formDate,
        description:
            _formDescription.trim().isEmpty ? null : _formDescription.trim(),
      );

      if (mounted) {
        setState(() {
          _expenses.insert(0, expense);
          _isSaving = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perbelanjaan telah direkod.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat menyimpan perbelanjaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openAddCategoryDialog() async {
    String name = '';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kategori Baru'),
          content: Form(
            key: formKey,
            child: TextFormField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama kategori',
                hintText: 'Contoh: Sewa Kedai',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => name = value,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Sila masukkan nama kategori';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final trimmed = name.trim();
                // Generate a simple slug key.
                final slug = trimmed
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                    .replaceAll(RegExp(r'^_+|_+$'), '');

                setState(() {
                  _categoryLabels[slug.isEmpty ? trimmed : slug] = trimmed;
                  _formCategory = slug.isEmpty ? trimmed : slug;
                });

                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perbelanjaan'),
            Text(
              'Rekod semua kos perniagaan',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Rekod Belanja'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSummary(),
                    const SizedBox(height: 12),
                    _buildCategorySummary(),
                    const SizedBox(height: 12),
                    _buildExpensesList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSummary() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jumlah Perbelanjaan',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(_totalAll),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.receipt_long,
              color: AppColors.primary,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Ringkasan mengikut kategori',
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
            children: [
              _buildCategoryChip(
                label: 'Semua',
                amount: _totalAll,
                isSelected: _selectedCategory == 'all',
                onTap: () => setState(() => _selectedCategory = 'all'),
              ),
              ..._categoryLabels.entries.map((entry) {
                final amount = _categoryTotals[entry.key] ?? 0.0;
                return _buildCategoryChip(
                  label: entry.value,
                  amount: amount,
                  isSelected: _selectedCategory == entry.key,
                  onTap: () {
                    setState(() {
                      _selectedCategory =
                          _selectedCategory == entry.key ? 'all' : entry.key;
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required double amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long,
                size: 40,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tiada perbelanjaan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedCategory == 'all'
                    ? 'Mulakan dengan merekod perbelanjaan pertama anda.'
                    : 'Tiada perbelanjaan untuk kategori ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _filteredExpenses.map((expense) {
        final isToday =
            DateUtils.isSameDay(expense.expenseDate, DateTime.now());
        final categoryLabel = _categoryLabels[expense.category] ??
            expense.category.toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              categoryLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy', 'ms_MY')
                                .format(expense.expenseDate),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
                        expense.notes ?? 'Tiada penerangan',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-${_formatCurrency(expense.amount)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}


