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
import '../../../data/models/expense.dart';

/// Parsed receipt data from OCR
class ParsedReceipt {
  double? amount;
  String? date;
  String? merchant;
  List<ParsedReceiptItem> items;
  String rawText;
  String category; // Auto-detected category from OCR

  ParsedReceipt({
    this.amount,
    this.date,
    this.merchant,
    this.items = const [],
    this.rawText = '',
    this.category = 'lain',
  });

  factory ParsedReceipt.fromJson(Map<String, dynamic> json) {
    return ParsedReceipt(
      amount: (json['amount'] as num?)?.toDouble(),
      date: json['date'] as String?,
      merchant: json['merchant'] as String?,
      rawText: json['rawText'] as String? ?? '',
      category: json['category'] as String? ?? 'lain',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => ParsedReceiptItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Receipt item from OCR parsing (temporary, will be converted to ReceiptItem)
class ParsedReceiptItem {
  final String name;
  final double price;

  ParsedReceiptItem({required this.name, required this.price});

  factory ParsedReceiptItem.fromJson(Map<String, dynamic> json) {
    return ParsedReceiptItem(
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
  
  // Zoom controls
  double _zoomLevel = 1.0;
  double _minZoom = 0.5;  // Allow zoom out to 0.5x for large receipts
  double _maxZoom = 4.0;
  bool _supportsZoom = false;

  // States
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _imageDataUrl;
  Uint8List? _imageBytes;
  ParsedReceipt? _parsedReceipt;
  String? _ocrError;
  String? _storagePathFromOCR; // Storage path returned by OCR Edge Function

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
    
    // Initialize camera after a short delay to prevent immediate permission popup
    // This helps prevent app hang when permission dialog appears
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _initCamera();
      }
    });
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
      // Small delay to prevent immediate permission popup that might cause hang
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      // Check if mediaDevices is available
      if (html.window.navigator.mediaDevices == null) {
        throw Exception('Kamera tidak disokong dalam browser ini. Sila gunakan browser moden seperti Chrome, Firefox, atau Edge.');
      }

      // Create video element
      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain' // Changed from 'cover' to 'contain' - show full camera view without zoom
        ..style.transformOrigin = 'center center';

      // Register platform view
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _videoElement!,
      );

      // Check permission status first (if supported)
      try {
        final permissionStatus = await html.window.navigator.permissions?.query({'name': 'camera'});
        if (permissionStatus != null && permissionStatus.state == 'denied') {
          throw Exception('Akses kamera telah ditolak. Sila benarkan akses kamera dalam tetapan browser anda.');
        }
      } catch (e) {
        // Permission API not supported, continue anyway
        // This is fine, we'll catch the error from getUserMedia
      }

      // Request camera access - let browser choose best resolution
      // Don't force aspect ratio constraint - let camera use its native aspect ratio
      // This prevents zoom/crop issues
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'environment', // Back camera
          'width': {'ideal': 1920}, // High quality
          'height': {'ideal': 1080}, // High quality
          // Don't force aspectRatio - let camera use native ratio
        },
        'audio': false,
      });

      if (_mediaStream != null) {
        _videoElement!.srcObject = _mediaStream;
        await _videoElement!.play();
        
        // Check if device supports native zoom (optional, not all browsers support this)
        _supportsZoom = true; // We'll use CSS transform for universal support
        
        if (mounted) {
          setState(() {
            _isCameraReady = true;
            _isCameraError = false;
            _zoomLevel = 1.0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal akses kamera';
        
        // Provide user-friendly error messages
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('notallowed') || errorString.contains('permission denied')) {
          errorMsg = 'Akses kamera ditolak. Sila benarkan akses kamera dalam tetapan browser dan cuba lagi.';
        } else if (errorString.contains('notfound') || errorString.contains('no camera')) {
          errorMsg = 'Tiada kamera dijumpai. Sila pastikan peranti anda mempunyai kamera.';
        } else if (errorString.contains('notreadable') || errorString.contains('could not start')) {
          errorMsg = 'Kamera sedang digunakan oleh aplikasi lain. Sila tutup aplikasi lain dan cuba lagi.';
        } else if (errorString.contains('overconstrained') || errorString.contains('constraint')) {
          errorMsg = 'Kamera tidak menyokong resolusi yang diperlukan. Cuba gunakan kamera lain.';
        } else {
          errorMsg = 'Gagal akses kamera: ${e.toString()}';
        }
        
        setState(() {
          _isCameraError = true;
          _cameraErrorMsg = errorMsg;
        });
      }
    }
  }
  
  /// Apply zoom to camera using CSS transform
  void _applyZoom(double zoom) {
    if (_videoElement == null) return;
    
    // Clamp zoom level
    zoom = zoom.clamp(_minZoom, _maxZoom);
    
    // Apply CSS transform for zoom effect
    _videoElement!.style.transform = 'scale($zoom)';
    
    setState(() {
      _zoomLevel = zoom;
    });
  }
  
  /// Zoom in
  void _zoomIn() {
    _applyZoom(_zoomLevel + 0.5);
  }
  
  /// Zoom out
  void _zoomOut() {
    _applyZoom(_zoomLevel - 0.5);
  }

  /// Stop camera
  void _stopCamera() {
    _mediaStream?.getTracks().forEach((track) => track.stop());
    _mediaStream = null;
    _videoElement?.pause();
    _videoElement?.srcObject = null;
    _zoomLevel = 1.0; // Reset zoom
  }

  /// Capture frame from live camera
  /// Captures exactly what user sees on screen (no zoom/crop)
  Future<void> _captureFromLiveCamera() async {
    if (_videoElement == null || !_isCameraReady) return;

    setState(() => _isCapturing = true);

    try {
      // Get actual video dimensions (what camera is capturing)
      final videoWidth = _videoElement!.videoWidth;
      final videoHeight = _videoElement!.videoHeight;
      
      if (videoWidth == 0 || videoHeight == 0) {
        throw Exception('Camera dimensions not available');
      }

      // Create canvas with actual video dimensions
      // This captures the full camera view (what user sees with objectFit: contain)
      final canvas = html.CanvasElement(
        width: videoWidth,
        height: videoHeight,
      );
      final ctx = canvas.context2D;
      
      // Draw the video frame directly - this captures what user sees
      // drawImage signature: drawImage(image, dx, dy, [dWidth, dHeight])
      ctx.drawImageScaled(_videoElement!, 0, 0, videoWidth, videoHeight);

      // Convert to base64 with high quality (0.90 for better OCR accuracy)
      final dataUrl = canvas.toDataUrl('image/jpeg', 0.90);
      final base64Data = dataUrl.split(',').last;
      final bytes = base64Decode(base64Data);

      // Stop camera after capture
      _stopCamera();

      setState(() {
        _imageDataUrl = dataUrl;
        _imageBytes = bytes;
        _isCameraReady = false;
      });

      // Process OCR immediately with original image
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

    // Process OCR immediately with original image
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

      // Call Supabase Edge Function for OCR (with image upload option)
      final response = await supabase.functions.invoke(
        'OCR-Cloud-Vision',
        body: {
          'imageBase64': base64Image,
          'uploadImage': true, // Request Edge Function to upload image
        },
      );

      if (response.status != 200) {
        throw Exception('OCR failed: ${response.data?['error'] ?? 'Unknown error'}');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'OCR processing failed');
      }

      final parsed = ParsedReceipt.fromJson(data['parsed'] as Map<String, dynamic>);
      
      // Check if Edge Function uploaded image and returned storage path
      final storagePathFromOCR = data['storagePath'] as String?;
      if (storagePathFromOCR != null) {
        debugPrint('✅ Image uploaded by OCR Edge Function: $storagePathFromOCR');
      }
      
      setState(() {
        _parsedReceipt = parsed;
        _storagePathFromOCR = storagePathFromOCR; // Store for use when saving
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
    // Auto-fill amount
    if (parsed.amount != null && parsed.amount! > 0) {
      _amountController.text = parsed.amount!.toStringAsFixed(2);
    }

    // Auto-fill date
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

    // Auto-fill merchant
    if (parsed.merchant != null && parsed.merchant!.isNotEmpty) {
      _merchantController.text = parsed.merchant!;
    }

    // Use category from Edge Function (already detected with better logic)
    _selectedCategory = parsed.category;

    setState(() {});
  }

  /// Auto-detect category from receipt content (fallback if OCR doesn't detect)
  String _detectCategory(ParsedReceipt parsed) {
    // Use merchant and raw text for category detection (items no longer extracted)
    final rawTextSample = parsed.rawText.length > 500 
        ? parsed.rawText.substring(0, 500)
        : parsed.rawText;
    final text = [
      parsed.merchant ?? '',
      rawTextSample,
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila isi semua maklumat yang diperlukan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amountText = _amountController.text.trim();
      final amount = double.tryParse(amountText) ?? 0;
      
      if (amount <= 0) {
        throw Exception('Jumlah tidak sah: $amountText');
      }

      // Upload original image to Supabase Storage
      String? receiptImageUrl;
      
      if (_imageBytes != null) {
        try {
          // Use storage path from OCR if available, otherwise upload now
          if (_storagePathFromOCR != null) {
            // OCR Edge Function already uploaded the image
            receiptImageUrl = _storagePathFromOCR;
            debugPrint('✅ Using image uploaded by OCR: $receiptImageUrl');
          } else {
            // Upload original image using ReceiptStorageService
            receiptImageUrl = await ReceiptStorageService.uploadReceipt(
              imageBytes: _imageBytes!,
              fileName: 'receipt-${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            debugPrint('✅ Original image uploaded: $receiptImageUrl');
          }
        } catch (uploadError) {
          debugPrint('❌ Image upload failed: $uploadError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Amaran: Gagal upload gambar. Rekod akan disimpan tanpa gambar. Error: ${uploadError.toString()}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      // Build description from merchant and notes
      String description = _merchantController.text.isNotEmpty
          ? _merchantController.text
          : 'Scan Resit';
      if (_notesController.text.isNotEmpty) {
        description = '$description\n${_notesController.text}';
      }

      // Build structured receipt data from parsed receipt (simplified - no items)
      ReceiptData? receiptData;
      if (_parsedReceipt != null) {
        final merchantText = _merchantController.text.trim();
        
        receiptData = ReceiptData(
          merchant: _parsedReceipt!.merchant ?? (merchantText.isEmpty ? null : merchantText),
          date: _parsedReceipt!.date ?? DateFormat('yyyy-MM-dd').format(_selectedDate),
          items: [], // Items extraction removed - only extract 4 fields: merchant, date, category, amount
          total: amount,
        );
      }

      // Log receipt URL before saving
      debugPrint('📝 Saving expense with receiptImageUrl: $receiptImageUrl');
      
      final savedExpense = await _repo.createExpense(
        amount: amount,
        category: _selectedCategory,
        expenseDate: _selectedDate,
        description: description,
        receiptImageUrl: receiptImageUrl, // Original image
        receiptData: receiptData,
      );

      // Verify receipt URL was saved
      debugPrint('✅ Expense saved with ID: ${savedExpense.id}');
      debugPrint('📸 Receipt URL in saved expense: ${savedExpense.receiptImageUrl}');

      if (mounted) {
        final message = receiptImageUrl != null
            ? 'Perbelanjaan berjaya disimpan dengan gambar resit!'
            : 'Perbelanjaan berjaya disimpan (tanpa gambar)';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: receiptImageUrl != null ? AppColors.success : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Save expense error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      _storagePathFromOCR = null;
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
      body: _imageDataUrl == null
          ? _buildLiveCameraView()
          : _buildResultView(),
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCameraError = false;
                      _cameraErrorMsg = null;
                    });
                    _initCamera(); // Retry camera access
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Cuba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
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
        // Match actual camera aspect ratio to prevent zoom/crop issues
        if (_isCameraReady && _videoElement != null)
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Get actual camera aspect ratio from video element
                final videoWidth = _videoElement!.videoWidth.toDouble();
                final videoHeight = _videoElement!.videoHeight.toDouble();
                final cameraAspectRatio = videoWidth > 0 && videoHeight > 0 
                    ? videoWidth / videoHeight 
                    : 16 / 9; // Fallback to 16:9
                
                // Calculate viewfinder size based on camera aspect ratio
                // Use 90% of screen width for better receipt visibility
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                final maxWidth = screenWidth * 0.90;
                final maxHeight = screenHeight * 0.75;
                
                double viewfinderWidth, viewfinderHeight;
                
                // Calculate based on camera aspect ratio
                if (cameraAspectRatio > 1) {
                  // Landscape camera
                  viewfinderWidth = maxWidth;
                  viewfinderHeight = maxWidth / cameraAspectRatio;
                  if (viewfinderHeight > maxHeight) {
                    viewfinderHeight = maxHeight;
                    viewfinderWidth = maxHeight * cameraAspectRatio;
                  }
                } else {
                  // Portrait camera
                  viewfinderHeight = maxHeight;
                  viewfinderWidth = maxHeight * cameraAspectRatio;
                  if (viewfinderWidth > maxWidth) {
                    viewfinderWidth = maxWidth;
                    viewfinderHeight = maxWidth / cameraAspectRatio;
                  }
                }
                
                return Container(
                  width: viewfinderWidth,
                  height: viewfinderHeight,
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
                      _buildScanningLine(maxHeight: viewfinderHeight),
                    ],
                  ),
                );
              },
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

        // Zoom controls (right side - positioned for easy thumb access)
        if (_isCameraReady)
          Positioned(
            right: 16,
            bottom: 180, // Lower position for one-hand operation
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom in button
                  GestureDetector(
                    onTap: _zoomIn,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _zoomLevel >= _maxZoom 
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom level indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom out button
                  GestureDetector(
                    onTap: _zoomOut,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _zoomLevel <= _minZoom 
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
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
  Widget _buildScanningLine({double maxHeight = 500}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
          top: value * (maxHeight - 20), // Use dynamic height
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
    if (_videoElement == null) return const SizedBox.shrink();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Match viewfinder dimensions (same calculation as viewfinder)
    final videoWidth = _videoElement!.videoWidth.toDouble();
    final videoHeight = _videoElement!.videoHeight.toDouble();
    final cameraAspectRatio = videoWidth > 0 && videoHeight > 0 
        ? videoWidth / videoHeight 
        : 16 / 9;
    
    final maxWidth = screenWidth * 0.90;
    final maxHeight = screenHeight * 0.75;
    
    double viewfinderWidth, viewfinderHeight;
    
    if (cameraAspectRatio > 1) {
      viewfinderWidth = maxWidth;
      viewfinderHeight = maxWidth / cameraAspectRatio;
      if (viewfinderHeight > maxHeight) {
        viewfinderHeight = maxHeight;
        viewfinderWidth = maxHeight * cameraAspectRatio;
      }
    } else {
      viewfinderHeight = maxHeight;
      viewfinderWidth = maxHeight * cameraAspectRatio;
      if (viewfinderWidth > maxWidth) {
        viewfinderWidth = maxWidth;
        viewfinderHeight = maxWidth / cameraAspectRatio;
      }
    }
    
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ViewfinderOverlayPainter(
          viewfinderRect: Rect.fromCenter(
            center: Offset(
              screenWidth / 2,
              screenHeight / 2 - 40,
            ),
            width: viewfinderWidth,
            height: viewfinderHeight,
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
                      minLines: 3,
                      maxLines: null, // Expandable - grows as user types or content expands
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Nota / Item (expandable)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        helperText: 'Tarik untuk expand atau scroll untuk baca semua',
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
