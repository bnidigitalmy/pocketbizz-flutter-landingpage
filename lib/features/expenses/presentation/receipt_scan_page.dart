import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

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

/// Receipt Scan Page - Live Camera + Google Cloud Vision OCR
class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  final _repo = ExpensesRepositorySupabase();
  final _picker = ImagePicker();

  // Camera elements
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  bool _isCameraReady = false;
  bool _isCameraError = false;
  String? _cameraErrorMsg;
  final String _viewId = 'receipt-camera-${DateTime.now().millisecondsSinceEpoch}';

  // States
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _imageDataUrl;
  Uint8List? _imageBytes;
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
    
    // Initialize camera immediately
    _initCamera();
  }

  @override
  void dispose() {
    _stopCamera();
    _amountController.dispose();
    _dateController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Initialize live camera
  Future<void> _initCamera() async {
    try {
      // Create video element
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      // Register platform view
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      // Request camera access (prefer back camera for receipt scanning)
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment', // Back camera
          'width': {'ideal': 1280},
          'height': {'ideal': 1920},
        },
        'audio': false,
      });

      if (_mediaStream != null) {
        _videoElement!.srcObject = _mediaStream;
        await _videoElement!.play();
        
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _isCameraError = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMsg = e.toString();
        });
      }
    }
  }

  /// Stop camera
  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
    _videoElement?.pause();
    _videoElement?.srcObject = null;
  }

  /// Capture frame from live camera
  Future<void> _captureFromLiveCamera() async {
    if (_videoElement == null || !_isCameraReady) return;

    setState(() => _isCapturing = true);

    try {
      // Create canvas to capture frame
      final canvas = html.CanvasElement(
        width: _videoElement!.videoWidth,
        height: _videoElement!.videoHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(_videoElement!, 0, 0);

      // Convert to base64
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
      final base64Data = dataUrl.split(',').last;
      final bytes = base64Decode(base64Data);

      // Stop camera after capture
      _stopCamera();

      setState(() {
        _imageDataUrl = dataUrl;
        _imageBytes = bytes;
        _isCameraReady = false;
      });

      // Process with OCR
      await _processImageBytes(bytes);

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

  /// Pick image from gallery (fallback)
  Future<void> _pickFromGallery() async {
    _stopCamera(); // Stop camera when switching to gallery
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
      } else {
        // User cancelled, restart camera
        _initCamera();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _initCamera();
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Process XFile image (from gallery)
  Future<void> _processImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = image.mimeType ?? 'image/jpeg';
    final dataUrl = 'data:$mimeType;base64,$base64Image';

    setState(() {
      _imageDataUrl = dataUrl;
      _imageBytes = bytes;
      _isCameraReady = false;
    });

    await _processImageBytes(bytes);
  }

  /// Process image bytes with Google Cloud Vision OCR
  Future<void> _processImageBytes(Uint8List bytes) async {
    setState(() {
      _isProcessing = true;
      _ocrError = null;
    });

    try {
      final base64Image = base64Encode(bytes);

      // Call Supabase Edge Function for OCR
      final response = await supabase.functions.invoke(
        'OCR-Cloud-Vision',
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
      try {
        final parts = parsed.date!.split(RegExp(r'[\/\-.]'));
        if (parts.length == 3) {
          int day, month, year;
          if (parts[0].length == 4) {
            year = int.parse(parts[0]);
            month = int.parse(parts[1]);
            day = int.parse(parts[2]);
          } else {
            day = int.parse(parts[0]);
            month = int.parse(parts[1]);
            year = int.parse(parts[2]);
            if (year < 100) year += 2000;
          }
          _selectedDate = DateTime(year, month, day);
          _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
        }
      } catch (_) {}
    }

    if (parsed.merchant != null) {
      _merchantController.text = parsed.merchant!;
    }

    _selectedCategory = _detectCategory(parsed);

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
        text.contains('aeon') ||
        text.contains('jaya grocer')) {
      return 'bahan';
    }
    return 'lain';
  }

  /// Save expense to database
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount <= 0) {
        throw Exception('Jumlah tidak sah');
      }

      // Upload receipt image to storage first
      String? receiptImageUrl;
      if (_imageBytes != null) {
        receiptImageUrl = await ReceiptStorageService.uploadReceipt(
          imageBytes: _imageBytes!,
        );
      }

      // Build description from merchant and notes
      String description = _merchantController.text.isNotEmpty
          ? _merchantController.text
          : 'Scan Resit';
      if (_notesController.text.isNotEmpty) {
        description = '$description\n${_notesController.text}';
      }

      await _repo.createExpense(
        amount: amount,
        category: _selectedCategory,
        expenseDate: _selectedDate,
        description: description,
        receiptImageUrl: receiptImageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perbelanjaan berjaya disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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
    _initCamera();
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
      body: _imageDataUrl == null ? _buildLiveCameraView() : _buildResultView(),
    );
  }

  /// Live camera view with real viewfinder
  Widget _buildLiveCameraView() {
    return Stack(
      children: [
        // Live camera preview (full screen)
        if (_isCameraReady)
          Positioned.fill(
            child: HtmlElementView(viewType: _viewId),
          )
        else if (_isCameraError)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Gagal akses kamera',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 8),
                Text(
                  _cameraErrorMsg ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pilih dari Galeri'),
                ),
              ],
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // Viewfinder overlay (yellow border that frames the receipt)
        if (_isCameraReady)
          Center(
            child: Container(
              width: 300,
              height: 420,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner accents (thicker)
                  _buildCornerAccent(top: 0, left: 0, isTop: true, isLeft: true),
                  _buildCornerAccent(top: 0, right: 0, isTop: true, isLeft: false),
                  _buildCornerAccent(bottom: 0, left: 0, isTop: false, isLeft: true),
                  _buildCornerAccent(bottom: 0, right: 0, isTop: false, isLeft: false),
                  
                  // Scanning line animation
                  _buildScanningLine(),
                ],
              ),
            ),
          ),

        // Dark overlay outside viewfinder
        if (_isCameraReady) _buildDarkOverlay(),

        // Instructions text
        if (_isCameraReady)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Text(
              'Letakkan resit dalam bingkai kuning',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
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
                // Capture button (large circular)
                GestureDetector(
                  onTap: (_isCapturing || !_isCameraReady) ? null : _captureFromLiveCamera,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isCapturing ? Colors.grey : Colors.white.withOpacity(0.3),
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Gallery button
                TextButton.icon(
                  onPressed: _isCapturing ? null : _pickFromGallery,
                  icon: Icon(
                    Icons.photo_library,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  label: Text(
                    'Pilih dari Galeri',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Memproses resit...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Build corner accent for viewfinder
  Widget _buildCornerAccent({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool isTop,
    required bool isLeft,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Colors.amber, width: 5) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Colors.amber, width: 5) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Colors.amber, width: 5) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Colors.amber, width: 5) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Build scanning line animation
  Widget _buildScanningLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
          top: value * 400,
          left: 10,
          right: 10,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.amber.withOpacity(0.8),
                  Colors.amber,
                  Colors.amber.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isCameraReady) {
          setState(() {}); // Restart animation
        }
      },
    );
  }

  /// Build dark overlay outside viewfinder
  Widget _buildDarkOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ViewfinderOverlayPainter(
          viewfinderRect: Rect.fromCenter(
            center: Offset(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2 - 40,
            ),
            width: 300,
            height: 420,
          ),
        ),
      ),
    );
  }

  /// Result view with image preview, OCR text, and editable form
  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (_imageDataUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _imageBytes!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),

          // OCR Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _ocrError == null
                  ? AppColors.success.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _ocrError == null ? AppColors.success : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _ocrError == null ? Icons.check_circle : Icons.warning,
                  color: _ocrError == null ? AppColors.success : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ocrError == null
                        ? 'OCR berjaya - Google Cloud Vision'
                        : 'OCR ralat: $_ocrError',
                    style: TextStyle(
                      color: _ocrError == null ? AppColors.success : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Editable form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Semak & Sahkan Maklumat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sila semak maklumat yang dikesan dan betulkan jika perlu sebelum simpan.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Jumlah (RM)*',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Sila masukkan jumlah';
                        if (double.tryParse(v) == null) return 'Jumlah tidak sah';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date field
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Tarikh',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
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

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _categoryLabels.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Merchant field
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Peniaga/Kedai',
                        prefixIcon: Icon(Icons.store),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Nota / Item',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
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
                            borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 16),

          // Raw OCR text (collapsible)
          if (_parsedReceipt != null && _parsedReceipt!.rawText.isNotEmpty)
            ExpansionTile(
              title: const Text(
                'Teks Resit Asal (OCR)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Custom painter for dark overlay outside viewfinder
class _ViewfinderOverlayPainter extends CustomPainter {
  final Rect viewfinderRect;

  _ViewfinderOverlayPainter({required this.viewfinderRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw full screen
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Create path with hole
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(viewfinderRect, const Radius.circular(12)));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
