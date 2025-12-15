import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/receipt_storage_service.dart';
import '../../../data/repositories/expenses_repository_supabase.dart';

/// Parsed receipt data from OCR
class ParsedReceipt {
  double? amount;
  String? date;
  String? merchant;
  List<ReceiptItem> items;
  String rawText;

  ParsedReceipt({
    this.amount,
    this.date,
    this.merchant,
    this.items = const [],
    this.rawText = '',
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    return ParsedReceipt(
      amount: (json['amount'] as num?)?.toDouble(),
      date: json['date'] as String?,
      merchant: json['merchant'] as String?,
      rawText: json['rawText'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => ReceiptItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ReceiptItem {
  final String name;
  final double price;

  ReceiptItem({required this.name, required this.price});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Receipt Scan Page - Camera/Gallery capture + Google Cloud Vision OCR + Verify before save
class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  final _repo = ExpensesRepositorySupabase();
  final _picker = ImagePicker();

  // States
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _imageDataUrl;
  Uint8List? _imageBytes; // Store image bytes for upload
  ParsedReceipt? _parsedReceipt;
  String? _ocrError;

  // Editable form fields (after OCR)
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  String _selectedCategory = 'lain';
  DateTime _selectedDate = DateTime.now();

  // Category options
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
    _amountController = TextEditingController();
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );
    _merchantController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Capture image from camera
  Future<void> _captureFromCamera() async {
    setState(() => _isCapturing = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    setState(() => _isCapturing = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Process captured/picked image with Google Cloud Vision OCR
  Future<void> _processImage(XFile image) async {
    setState(() {
      _isProcessing = true;
      _ocrError = null;
    });

    try {
      // Read image as base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = image.mimeType ?? 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      setState(() {
        _imageDataUrl = dataUrl;
        _imageBytes = bytes; // Store for later upload
      });

      // Call Supabase Edge Function for OCR
      final response = await supabase.functions.invoke(
        'ocr-receipt',
        body: {'imageBase64': base64Image},
      );

      if (response.status != 200) {
        throw Exception('OCR failed: ${response.data?['error'] ?? 'Unknown error'}');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'OCR processing failed');
      }

      final parsed = ParsedReceipt.fromJson(data['parsed'] as Map<String, dynamic>);
      
      setState(() {
        _parsedReceipt = parsed;
      });

      // Pre-fill form fields
      _prefillFormFromParsed(parsed);

    } catch (e) {
      setState(() => _ocrError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat OCR: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Pre-fill form fields from parsed receipt
  void _prefillFormFromParsed(ParsedReceipt parsed) {
    if (parsed.amount != null) {
      _amountController.text = parsed.amount!.toStringAsFixed(2);
    }

    if (parsed.date != null) {
      // Try to parse the date
      try {
        final parts = parsed.date!.split(RegExp(r'[\/\-.]'));
        if (parts.length == 3) {
          int day, month, year;
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            year = int.parse(parts[0]);
            month = int.parse(parts[1]);
            day = int.parse(parts[2]);
          } else {
            // DD/MM/YYYY
            day = int.parse(parts[0]);
            month = int.parse(parts[1]);
            year = int.parse(parts[2]);
            if (year < 100) year += 2000;
          }
          _selectedDate = DateTime(year, month, day);
          _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
        }
      } catch (_) {
        // Keep default date
      }
    }

    if (parsed.merchant != null) {
      _merchantController.text = parsed.merchant!;
    }

    // Auto-detect category from merchant/items
    _selectedCategory = _detectCategory(parsed);

    // Build notes from items
    if (parsed.items.isNotEmpty) {
      final itemsText = parsed.items
          .map((i) => '${i.name}: RM${i.price.toStringAsFixed(2)}')
          .join('\n');
      _notesController.text = itemsText;
    }

    setState(() {});
  }

  /// Auto-detect category from receipt content
  String _detectCategory(ParsedReceipt parsed) {
    final text = [
      parsed.merchant ?? '',
      ...parsed.items.map((i) => i.name),
    ].join(' ').toLowerCase();

    if (text.contains('petrol') ||
        text.contains('petronas') ||
        text.contains('shell') ||
        text.contains('caltex') ||
        text.contains('bhp') ||
        text.contains('minyak')) {
      return 'minyak';
    }
    if (text.contains('plastik') ||
        text.contains('beg') ||
        text.contains('packaging') ||
        text.contains('kotak')) {
      return 'plastik';
    }
    if (text.contains('gaji') || text.contains('upah') || text.contains('bayaran pekerja')) {
      return 'upah';
    }
    if (text.contains('tepung') ||
        text.contains('gula') ||
        text.contains('mentega') ||
        text.contains('telur') ||
        text.contains('susu') ||
        text.contains('bahan') ||
        text.contains('grocer') ||
        text.contains('mydin') ||
        text.contains('econsave') ||
        text.contains('giant') ||
        text.contains('tesco') ||
        text.contains('aeon')) {
      return 'bahan';
    }

    return 'lain';
  }

  /// Save expense
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final amount = double.parse(_amountController.text);
      String? notes = _notesController.text.trim();
      if (_merchantController.text.isNotEmpty) {
        notes = '${_merchantController.text}\n$notes'.trim();
      }

      // Upload receipt image to Supabase Storage if available
      String? receiptImageUrl;
      if (_imageBytes != null) {
        try {
          receiptImageUrl = await ReceiptStorageService.uploadReceipt(
            imageBytes: _imageBytes!,
          );
        } catch (e) {
          // Log error but continue - receipt upload is not critical
          print('⚠️ Failed to upload receipt image: $e');
        }
      }

      await _repo.createExpense(
        category: _selectedCategory,
        amount: amount,
        expenseDate: _selectedDate,
        description: notes.isEmpty ? null : notes,
        receiptImageUrl: receiptImageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(receiptImageUrl != null 
                ? '✅ Perbelanjaan & resit berjaya disimpan!' 
                : '✅ Perbelanjaan berjaya disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Reset to capture new receipt
  void _resetScan() {
    setState(() {
      _imageDataUrl = null;
      _imageBytes = null;
      _parsedReceipt = null;
      _ocrError = null;
      _amountController.clear();
      _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _selectedDate = DateTime.now();
      _merchantController.clear();
      _notesController.clear();
      _selectedCategory = 'lain';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _imageDataUrl == null ? Colors.black : AppColors.background,
      appBar: AppBar(
        title: const Text('Scan Resit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_imageDataUrl != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan semula',
              onPressed: _resetScan,
            ),
        ],
      ),
      body: _imageDataUrl == null ? _buildCaptureView() : _buildResultView(),
    );
  }

  /// Camera/Gallery capture view (like Bank Islam scan page)
  Widget _buildCaptureView() {
    return Stack(
      children: [
        // Dark background with scan frame
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scan frame indicator
              Container(
                width: 280,
                height: 380,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.amber, width: 4),
                            left: BorderSide(color: Colors.amber, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.amber, width: 4),
                            right: BorderSide(color: Colors.amber, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.amber, width: 4),
                            left: BorderSide(color: Colors.amber, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.amber, width: 4),
                            right: BorderSide(color: Colors.amber, width: 4),
                          ),
                        ),
                      ),
                    ),
                    // Center icon
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Letakkan resit dalam bingkai',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Instructions
              Text(
                'Ambil gambar resit atau pilih dari galeri',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Bottom action buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera capture button (main action)
                ElevatedButton.icon(
                  onPressed: _isCapturing ? null : _captureFromCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 24),
                  label: Text(
                    _isCapturing ? 'Membuka kamera...' : 'Ambil Gambar',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                // Gallery button (secondary action - like Maybank style)
                TextButton.icon(
                  onPressed: _isCapturing ? null : _pickFromGallery,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: const Text(
                    'Scan Resit dari Galeri',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Result view with image preview, OCR text, and editable form
  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Processing indicator
          if (_isProcessing)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Mengimbas resit...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Cloud Vision sedang memproses',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Image preview
          if (!_isProcessing && _imageDataUrl != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      _imageDataUrl!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _ocrError == null ? Icons.check_circle : Icons.warning,
                          color: _ocrError == null ? AppColors.success : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ocrError == null
                                ? 'OCR berjaya - Google Cloud Vision'
                                : 'OCR ralat: $_ocrError',
                            style: TextStyle(
                              fontSize: 13,
                              color: _ocrError == null ? AppColors.success : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Verify & Edit form
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.edit_note, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Semak & Sahkan Maklumat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sila semak maklumat yang dikesan dan betulkan jika perlu sebelum simpan.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah (RM)*',
                          border: OutlineInputBorder(),
                          prefixText: 'RM ',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          final v = double.tryParse(value ?? '');
                          if (v == null || v <= 0) {
                            return 'Masukkan jumlah yang sah';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Tarikh',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
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
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Merchant
                      TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Kedai/Vendor (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes / Items
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Penerangan / Item (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _isSaving ? 'Menyimpan...' : 'Simpan Perbelanjaan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Raw OCR text (collapsible)
            if (_parsedReceipt?.rawText.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  'Teks Resit Asal (OCR)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                leading: const Icon(Icons.text_snippet, size: 20),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _parsedReceipt!.rawText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
