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
                    _buildPageHeader(),
                    const SizedBox(height: 16),
                    _buildCategoryGrid(),
                    const SizedBox(height: 16),
                    _buildExpensesList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Page header with title + big "Tambah Perbelanjaan" button,
  /// similar to the original React mobile layout.
  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perbelanjaan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Rekod semua kos perniagaan',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openAddDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Tambah Perbelanjaan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Category summary in a 2-column grid of big cards,
  /// matching the original React mobile layout.
  Widget _buildCategoryGrid() {
    final categories = _categoryLabels.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan mengikut kategori',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final entry = categories[index];
            final amount = _categoryTotals[entry.key] ?? 0.0;
            final isSelected = _selectedCategory == entry.key;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory =
                      isSelected ? 'all' : entry.key;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                elevation: isSelected ? 3 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatCurrency(amount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
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


