import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../data/models/purchase_order.dart';
import '../../../data/repositories/purchase_order_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../drive_sync/utils/drive_sync_helper.dart';
import '../../../core/services/document_storage_service.dart';

// Conditional import for web
import 'dart:html' as html if (dart.library.html) 'dart:html';

/// Purchase Orders Page
/// Full-featured PO management dengan semua features dari React code
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final _poRepo = PurchaseOrderRepository(supabase);
  final _businessProfileRepo = BusinessProfileRepository();
  
  List<PurchaseOrder> _purchaseOrders = [];
  BusinessProfile? _businessProfile;
  bool _isLoading = true;
  
  // Selected PO for dialogs
  PurchaseOrder? _selectedPO;
  
  // Email form
  final _emailRecipientController = TextEditingController();
  final _emailNameController = TextEditingController();
  final _emailMessageController = TextEditingController();
  
  // Edit form
  final _editSupplierNameController = TextEditingController();
  final _editSupplierPhoneController = TextEditingController();
  final _editSupplierEmailController = TextEditingController();
  final _editSupplierAddressController = TextEditingController();
  final _editDeliveryAddressController = TextEditingController();
  final _editNotesController = TextEditingController();
  final _editExpectedDeliveryController = TextEditingController();
  final _editPaymentTermsController = TextEditingController();
  final _editPaymentMethodController = TextEditingController();
  final _editRequestedByController = TextEditingController();
  final _editDiscountController = TextEditingController();
  final _editTaxController = TextEditingController();
  final _editShippingController = TextEditingController();
  List<Map<String, dynamic>> _editItems = [];
  
  // Template form
  final _templateNameController = TextEditingController();
  
  // Templates list (placeholder)
  final List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPurchaseOrders(),
      _loadBusinessProfile(),
    ]);
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final profile = await _businessProfileRepo.getBusinessProfile();
      if (mounted) {
        setState(() {
          _businessProfile = profile;
        });
        debugPrint('Business profile loaded: ${profile?.businessName}, ${profile?.address}, ${profile?.phone}');
      }
    } catch (e) {
      // Business profile is optional, continue without it
      debugPrint('Failed to load business profile: $e');
    }
  }

  /// Ensure business profile is loaded before generating PDF
  Future<void> _ensureBusinessProfileLoaded() async {
    if (_businessProfile == null) {
      await _loadBusinessProfile();
    }
  }

  @override
  void dispose() {
    _emailRecipientController.dispose();
    _emailNameController.dispose();
    _emailMessageController.dispose();
    _editSupplierNameController.dispose();
    _editSupplierPhoneController.dispose();
    _editSupplierEmailController.dispose();
    _editSupplierAddressController.dispose();
    _editDeliveryAddressController.dispose();
    _editNotesController.dispose();
    _editExpectedDeliveryController.dispose();
    _editPaymentTermsController.dispose();
    _editPaymentMethodController.dispose();
    _editRequestedByController.dispose();
    _editDiscountController.dispose();
    _editTaxController.dispose();
    _editShippingController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() => _isLoading = true);
    
    try {
      final orders = await _poRepo.getAllPurchaseOrders(limit: 100);
      setState(() {
        _purchaseOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _poRepo.updateStatus(id, status);
      _loadPurchaseOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Status dikemaskini'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAsReceived(String id) async {
    try {
      await _poRepo.markAsReceived(id);
      _loadPurchaseOrders();
      
      // Wait a bit for stock to update via RPC function
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Barang Diterima! Stok telah dikemaskini. Dashboard akan refresh secara automatik.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
        
        // Force refresh after a short delay to ensure stock is updated
        // This helps if real-time subscription doesn't trigger immediately
        Future.delayed(const Duration(seconds: 1), () {
          // Trigger a manual refresh by navigating back and forth
          // This will cause didChangeDependencies to run in other pages
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deletePO(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Purchase Order?'),
        content: const Text('Adakah anda pasti mahu memadam PO ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _poRepo.deletePurchaseOrder(id);
        _loadPurchaseOrders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PO dipadam'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _duplicatePO(String id) async {
    try {
      await _poRepo.duplicatePurchaseOrder(id);
      _loadPurchaseOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PO diduplikasi sebagai Draft'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updatePO() async {
    if (_selectedPO == null) return;
    
    if (_editSupplierNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama supplier diperlukan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_editItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final updateData = {
        'supplier_name': _editSupplierNameController.text.trim(),
        'supplier_phone': _editSupplierPhoneController.text.trim().isEmpty 
            ? null 
            : _editSupplierPhoneController.text.trim(),
        'supplier_email': _editSupplierEmailController.text.trim().isEmpty 
            ? null 
            : _editSupplierEmailController.text.trim(),
        'supplier_address': _editSupplierAddressController.text.trim().isEmpty 
            ? null 
            : _editSupplierAddressController.text.trim(),
        'delivery_address': _editDeliveryAddressController.text.trim().isEmpty 
            ? null 
            : _editDeliveryAddressController.text.trim(),
        'notes': _editNotesController.text.trim().isEmpty 
            ? null 
            : _editNotesController.text.trim(),
        'expected_delivery_date': _editExpectedDeliveryController.text.trim().isEmpty 
            ? null 
            : _editExpectedDeliveryController.text.trim(),
        'payment_terms': _editPaymentTermsController.text.trim().isEmpty 
            ? '30 hari selepas penghantaran'
            : _editPaymentTermsController.text.trim(),
        'payment_method': _editPaymentMethodController.text.trim().isEmpty 
            ? 'Bank Transfer'
            : _editPaymentMethodController.text.trim(),
        'requested_by': _editRequestedByController.text.trim().isEmpty 
            ? null 
            : _editRequestedByController.text.trim(),
        'discount': double.tryParse(_editDiscountController.text) ?? 0.0,
        'tax': double.tryParse(_editTaxController.text) ?? 0.0,
        'shipping_charges': double.tryParse(_editShippingController.text) ?? 0.0,
        'items': _editItems.map((item) {
          return {
            'item_name': item['item_name'],
            'quantity': double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0,
            'unit': item['unit'] ?? 'pcs',
            'estimated_price': double.tryParse(item['estimated_price']?.toString() ?? '0') ?? 0.0,
            'notes': item['notes'],
          };
        }).toList(),
      };
      
      // Recalculate total
      double subtotal = 0.0;
      for (var item in _editItems) {
        final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        final price = double.tryParse(item['estimated_price']?.toString() ?? '0') ?? 0.0;
        subtotal += qty * price;
      }
      final discount = double.tryParse(_editDiscountController.text) ?? 0.0;
      final shipping = double.tryParse(_editShippingController.text) ?? 0.0;
      final tax = double.tryParse(_editTaxController.text) ?? 0.0;
      updateData['total_amount'] = subtotal - discount + shipping + tax;
      
      await _poRepo.updatePurchaseOrder(_selectedPO!.id, updateData);
      _loadPurchaseOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PO dikemaskini'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _shareWhatsApp(PurchaseOrder po) async {
    try {
      // Ensure business profile is loaded
      await _ensureBusinessProfileLoaded();
      
      // Generate PDF first
      final pdfBytes = await PDFGenerator.generatePOPDF(
        po,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );
      
      // Create message with PDF info
      final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(po.createdAt));
      
      var message = '📋 *PURCHASE ORDER*\n';
      message += '${_businessProfile?.businessName ?? 'PocketBizz'}\n\n';
      message += 'PO Number: *${po.poNumber}*\n';
      message += 'Tarikh: $date\n\n';
      
      message += '📤 *KEPADA:*\n';
      message += '${po.supplierName}\n';
      if (po.supplierPhone != null) message += 'Tel: ${po.supplierPhone}\n';
      if (po.supplierEmail != null) message += 'Email: ${po.supplierEmail}\n';
      if (po.supplierAddress != null) message += '${po.supplierAddress}\n';
      message += '\n';
      
      if (po.deliveryAddress != null) {
        message += '📍 *ALAMAT PENGHANTARAN:*\n';
        message += '${po.deliveryAddress}\n\n';
      }
      
      message += '📦 *SENARAI ITEM:*\n\n';
      
      for (var i = 0; i < po.items.length; i++) {
        final item = po.items[i];
        message += '${i + 1}. *${item.itemName}*\n';
        message += '   Kuantiti: ${item.quantity.toStringAsFixed(1)} ${item.unit}\n';
        if (item.estimatedPrice != null) {
          final price = item.estimatedPrice!;
          final total = price * item.quantity;
          message += '   Harga: RM ${price.toStringAsFixed(2)}\n';
          message += '   Jumlah: RM ${total.toStringAsFixed(2)}\n';
        }
        if (item.notes != null) {
          message += '   Nota: ${item.notes}\n';
        }
        message += '\n';
      }
      
      message += '${List.filled(30, '=').join()}\n';
      message += '💰 *JUMLAH: RM ${po.totalAmount.toStringAsFixed(2)}*\n\n';
      
      if (po.notes != null) {
        message += '📝 Nota: ${po.notes}\n\n';
      }
      
      message += '📎 *PDF Purchase Order telah dilampirkan*\n\n';
      message += 'Sila sahkan pesanan ini. Terima kasih! 🙏';
      
      // Auto-sync to Google Drive (non-blocking)
      final fileName = 'PO_${po.poNumber}_${DateFormat('yyyyMMdd').format(po.createdAt)}.pdf';
      // Auto-backup to Supabase Storage (non-blocking)
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'purchase_order',
        relatedEntityType: 'purchase_order',
        relatedEntityId: po.id,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: 'purchase_order',
        relatedEntityType: 'purchase_order',
        relatedEntityId: po.id,
      );

      // For mobile: Share PDF first, then open WhatsApp
      if (!kIsWeb) {
        // Share PDF file
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${po.poNumber}.pdf',
        );
        
        // Wait a bit for share dialog
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Open WhatsApp with message
      final encodedMessage = Uri.encodeComponent(message);
      final phoneNumber = po.supplierPhone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
      final whatsappUrl = phoneNumber.isNotEmpty
          ? 'https://wa.me/$phoneNumber?text=$encodedMessage'
          : 'https://wa.me/?text=$encodedMessage';
      
      await launchUrl(Uri.parse(whatsappUrl));
      
      if (mounted && !kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF telah dibuka untuk share. Selepas share PDF, buka WhatsApp untuk hantar mesej.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (mounted) {
        // For web, download PDF first
        await _downloadPDF(po);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF telah dimuat turun. Sila attach PDF dalam WhatsApp Web.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF(PurchaseOrder po) async {
    try {
      // Ensure business profile is loaded
      await _ensureBusinessProfileLoaded();
      
      // Generate PDF
      final pdfBytes = await PDFGenerator.generatePOPDF(
        po,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );
      
      if (kIsWeb) {
        // For web, trigger download
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', '${po.poNumber}.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dimuat turun!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For mobile, share the PDF
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${po.poNumber}.pdf',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dihasilkan! Pilih lokasi untuk simpan.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Auto-sync to Google Drive (non-blocking)
      final fileName = 'PO_${po.poNumber}_${DateFormat('yyyyMMdd').format(po.createdAt)}.pdf';
      // Auto-backup to Supabase Storage (non-blocking)
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'purchase_order',
        relatedEntityType: 'purchase_order',
        relatedEntityId: po.id,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: 'purchase_order',
        relatedEntityType: 'purchase_order',
        relatedEntityId: po.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPO(PurchaseOrder po) async {
    try {
      // Ensure business profile is loaded
      await _ensureBusinessProfileLoaded();
      
      // Generate PDF first
      final pdfBytes = await PDFGenerator.generatePOPDF(
        po,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );
      
      // Print directly using Printing.layoutPdf
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'PO_${po.poNumber}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PO sedang dicetak...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ralat mencetak PO: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareAsShoppingList(PurchaseOrder po) async {
    // Create a simple shopping list format (no PO details, just items)
    var list = '🛒 *SENARAI BELIAN*\n';
    list += 'PO: ${po.poNumber}\n';
    list += 'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(po.createdAt))}\n\n';
    
    list += '*Item yang perlu dibeli:*\n\n';
    
    for (var i = 0; i < po.items.length; i++) {
      final item = po.items[i];
      list += '${i + 1}. ${item.itemName}\n';
      list += '   Kuantiti: ${item.quantity.toStringAsFixed(1)} ${item.unit}\n';
      if (item.notes != null && item.notes!.isNotEmpty) {
        list += '   Nota: ${item.notes}\n';
      }
      list += '\n';
    }
    
    list += '\nJumlah: ${po.items.length} item';
    
    // Share via WhatsApp (without phone number - user can choose recipient)
    final encodedMessage = Uri.encodeComponent(list);
    final whatsappUrl = 'https://wa.me/?text=$encodedMessage';
    
    try {
      await launchUrl(Uri.parse(whatsappUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Senarai belian dibuka di WhatsApp. Pilih penerima (staff/pekerja/diri sendiri).'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _copyAsText(PurchaseOrder po) async {
    // Ensure business profile is loaded
    await _ensureBusinessProfileLoaded();
    
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(po.createdAt));
    
    var text = 'PURCHASE ORDER\n';
    text += '${_businessProfile?.businessName ?? 'PocketBizz'}\n\n';
    text += 'PO Number: ${po.poNumber}\n';
    text += 'Tarikh: $date\n\n';
    
    text += 'KEPADA:\n';
    text += '${po.supplierName}\n';
    if (po.supplierPhone != null) text += 'Tel: ${po.supplierPhone}\n';
    if (po.supplierEmail != null) text += 'Email: ${po.supplierEmail}\n';
    if (po.supplierAddress != null) text += '${po.supplierAddress}\n';
    text += '\n';
    
    if (po.deliveryAddress != null) {
      text += 'ALAMAT PENGHANTARAN:\n';
      text += '${po.deliveryAddress}\n\n';
    }
    
    text += 'SENARAI ITEM:\n\n';
    
    for (var i = 0; i < po.items.length; i++) {
      final item = po.items[i];
      text += '${i + 1}. ${item.itemName}\n';
      text += '   Kuantiti: ${item.quantity.toStringAsFixed(1)} ${item.unit}\n';
      if (item.estimatedPrice != null) {
        final price = item.estimatedPrice!;
        final total = price * item.quantity;
        text += '   Harga: RM ${price.toStringAsFixed(2)}\n';
        text += '   Jumlah: RM ${total.toStringAsFixed(2)}\n';
      }
      if (item.notes != null) {
        text += '   Nota: ${item.notes}\n';
      }
      text += '\n';
    }
    
    text += '${List.filled(30, '=').join()}\n';
    text += 'JUMLAH: RM ${po.totalAmount.toStringAsFixed(2)}\n\n';
    
    if (po.notes != null) {
      text += 'Nota: ${po.notes}\n\n';
    }
    
    await Clipboard.setData(ClipboardData(text: text));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PO disalin ke clipboard! Boleh paste ke mana-mana (email, notes, dll)'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openEditDialog(PurchaseOrder po) {
    setState(() {
      _selectedPO = po;
      _editSupplierNameController.text = po.supplierName;
      _editSupplierPhoneController.text = po.supplierPhone ?? '';
      _editSupplierEmailController.text = po.supplierEmail ?? '';
      _editSupplierAddressController.text = po.supplierAddress ?? '';
      _editDeliveryAddressController.text = po.deliveryAddress ?? '';
      _editNotesController.text = po.notes ?? '';
      _editExpectedDeliveryController.text = po.expectedDeliveryDate ?? '';
      _editPaymentTermsController.text = po.paymentTerms ?? '30 hari selepas penghantaran';
      _editPaymentMethodController.text = po.paymentMethod ?? 'Bank Transfer';
      _editRequestedByController.text = po.requestedBy ?? '';
      _editDiscountController.text = (po.discount ?? 0.0).toStringAsFixed(2);
      _editTaxController.text = (po.tax ?? 0.0).toStringAsFixed(2);
      _editShippingController.text = (po.shippingCharges ?? 0.0).toStringAsFixed(2);
      _editItems = po.items.map((item) {
        return {
          'id': item.id,
          'item_name': item.itemName,
          'quantity': item.quantity.toStringAsFixed(1),
          'unit': item.unit,
          'estimated_price': (item.estimatedPrice ?? 0.0).toStringAsFixed(2),
          'notes': item.notes ?? '',
        };
      }).toList();
    });
    _showEditDialog();
  }

  void _openEmailDialog(PurchaseOrder po) {
    setState(() {
      _selectedPO = po;
      _emailRecipientController.text = po.supplierEmail ?? '';
      _emailNameController.text = po.supplierName;
      _emailMessageController.clear();
    });
    _showEmailDialog();
  }

  void _showEditDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildEditDialog(),
    );
  }

  void _showEmailDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildEmailDialog(),
    );
  }

  void _showReceiveDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildReceiveDialog(),
    );
  }

  void _showSaveTemplateDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildSaveTemplateDialog(),
    );
  }

  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildTemplatesDialog(),
    );
  }

  void _showDuplicateDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildDuplicateDialog(),
    );
  }

  Future<void> _sendEmail() async {
    if (_selectedPO == null) return;
    
    if (_emailRecipientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email diperlukan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // Ensure business profile is loaded
      await _ensureBusinessProfileLoaded();
      
      // Generate PDF first
      final pdfBytes = await PDFGenerator.generatePOPDF(
        _selectedPO!,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
      );
      
      // Convert PDF to base64 for email attachment
      final pdfBase64 = base64Encode(pdfBytes);
      
      // Create email subject and body
      final subject = 'Purchase Order ${_selectedPO!.poNumber} - ${_businessProfile?.businessName ?? 'PocketBizz'}';
      final body = _emailMessageController.text.trim().isEmpty
          ? 'Sila lihat Purchase Order yang dilampirkan.\n\nTerima kasih!'
          : _emailMessageController.text.trim();
      
      // For web: Use mailto with data URI (limited support)
      // For mobile: Use mailto and share PDF separately
      if (kIsWeb) {
        // Web: Open mailto link (PDF attachment not directly supported via mailto)
        // User can download PDF and attach manually, or we can use a service
        final emailUrl = Uri(
          scheme: 'mailto',
          path: _emailRecipientController.text.trim(),
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        );
        
        await launchUrl(emailUrl);
        
        // Also trigger PDF download so user can attach it
        await _downloadPDF(_selectedPO!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email client dibuka. PDF telah dimuat turun - sila attach PDF tersebut.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Mobile: Use mailto and share PDF
        final emailUrl = Uri(
          scheme: 'mailto',
          path: _emailRecipientController.text.trim(),
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
        );
        
        await launchUrl(emailUrl);
        
        // Also share PDF so user can attach it
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: '${_selectedPO!.poNumber}.pdf',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email client dibuka. PDF telah dibuka untuk share - sila attach PDF tersebut.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
      
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _calculateStats() {
    final draft = _purchaseOrders.where((po) => po.status == 'draft').length;
    final sent = _purchaseOrders.where((po) => po.status == 'sent').length;
    final received = _purchaseOrders.where((po) => po.status == 'received').length;
    final totalValue = _purchaseOrders.fold<double>(
      0.0,
      (sum, po) => sum + po.totalAmount,
    );
    
    return {
      'draft': draft,
      'sent': sent,
      'received': received,
      'totalValue': totalValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
            Text('📦 Purchase Orders'),
            Text(
              'Urus pesanan pembelian dari supplier',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _showTemplatesDialog,
            tooltip: 'Templates',
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kembali ke Cart',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatsCard(
                          'Draft',
                          '${stats['draft']}',
                          Icons.access_time,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatsCard(
                          'Dihantar',
                          '${stats['sent']}',
                          Icons.send,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatsCard(
                          'Diterima',
                          '${stats['received']}',
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatsCard(
                          'Nilai Total',
                          'RM ${(stats['totalValue'] as double).toStringAsFixed(2)}',
                          Icons.inventory_2,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Purchase Orders List
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Senarai Purchase Orders',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _purchaseOrders.isEmpty
                                        ? 'Tiada purchase order'
                                        : '${_purchaseOrders.length} purchase order dijumpai',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_purchaseOrders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.description,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tiada Purchase Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Buat purchase order dari shopping cart',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.shopping_cart),
                                  label: const Text('Pergi ke Shopping Cart'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._purchaseOrders.map((po) => _buildPOCard(po)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrder po) {
    final statusColor = PurchaseOrder.getStatusColor(po.status);
    final statusIcon = PurchaseOrder.getStatusIcon(po.status);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedPO = po);
          _showDetailsDialog();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              po.poNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 14, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    po.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supplier: ${po.supplierName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Tarikh: ${DateFormat('dd MMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(po.createdAt))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Jumlah: RM ${po.totalAmount.toStringAsFixed(2)} • ${po.items.length} item',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // View button
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedPO = po);
                      _showDetailsDialog();
                    },
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Lihat'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  // PDF button
                  OutlinedButton(
                    onPressed: () => _downloadPDF(po),
                    child: const Icon(Icons.download, size: 16),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  // Status-specific actions
                  if (po.status == 'draft') ...[
                    OutlinedButton(
                      onPressed: () => _openEditDialog(po),
                      child: const Icon(Icons.edit, size: 16),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    // Action menu button - multiple options
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        switch (value) {
                          case 'whatsapp':
                            _updateStatus(po.id, 'sent');
                            await _shareWhatsApp(po);
                            break;
                          case 'mark_sent':
                            _updateStatus(po.id, 'sent');
                            break;
                          case 'print':
                            _printPO(po);
                            break;
                          case 'share_list':
                            _shareAsShoppingList(po);
                            break;
                          case 'copy_text':
                            _copyAsText(po);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'whatsapp',
                          child: Row(
                            children: [
                              Icon(Icons.chat, size: 18),
                              SizedBox(width: 8),
                              Text('WhatsApp ke Supplier'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'mark_sent',
                          child: Row(
                            children: [
                              Icon(Icons.send, size: 18),
                              SizedBox(width: 8),
                              Text('Tandakan sebagai Dihantar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print, size: 18),
                              SizedBox(width: 8),
                              Text('Cetak PO'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share_list',
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag, size: 18),
                              SizedBox(width: 8),
                              Text('Kongsi sebagai Senarai Belian'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'copy_text',
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 18),
                              SizedBox(width: 8),
                              Text('Salin sebagai Teks'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePO(po.id),
                    ),
                  ],
                  if (po.status == 'sent') ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _selectedPO = po);
                        _showReceiveDialog();
                      },
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Terima'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                  if (po.status == 'received') ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _selectedPO = po);
                        _showDuplicateDialog();
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Order Semula'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '✅ Selesai',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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


  void _showDetailsDialog() {
    if (_selectedPO == null) return;
    showDialog(
      context: context,
      builder: (context) => _buildDetailsDialog(),
    );
  }

  Widget _buildDetailsDialog() {
    final po = _selectedPO!;
    
    return AlertDialog(
      title: Text('Purchase Order: ${po.poNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PurchaseOrder.getStatusColor(po.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                po.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: PurchaseOrder.getStatusColor(po.status),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Supplier info
            _buildInfoRow('Supplier', po.supplierName),
            if (po.supplierPhone != null)
              _buildInfoRow('Telefon', po.supplierPhone!),
            if (po.supplierEmail != null)
              _buildInfoRow('Email', po.supplierEmail!),
            _buildInfoRow(
              'Tarikh Dibuat',
              DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(po.createdAt)),
            ),
            const SizedBox(height: 16),
            
            // Items table
            const Text(
              'Item Pesanan:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Kuantiti')),
                DataColumn(label: Text('Harga')),
                DataColumn(label: Text('Jumlah', textAlign: TextAlign.right)),
              ],
              rows: po.items.map((item) {
                final price = item.actualPrice ?? item.estimatedPrice ?? 0.0;
                final total = price * item.quantity;
                
                return DataRow(
                  cells: [
                    DataCell(Text(item.itemName)),
                    DataCell(Text('${item.quantity.toStringAsFixed(1)} ${item.unit}')),
                    DataCell(Text('RM ${price.toStringAsFixed(2)}')),
                    DataCell(Text(
                      'RM ${total.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                    )),
                  ],
                );
              }).toList(),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JUMLAH', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'RM ${po.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (po.notes != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow('Nota', po.notes!),
            ],
          ],
        ),
      ),
      actions: [
        // Action menu for multiple options
        PopupMenuButton<String>(
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_vert),
                SizedBox(width: 4),
                Text('Tindakan'),
              ],
            ),
          ),
          onSelected: (value) async {
            Navigator.pop(context); // Close details dialog first
            switch (value) {
              case 'whatsapp':
                if (po.status == 'draft') {
                  _updateStatus(po.id, 'sent');
                }
                await _shareWhatsApp(po);
                break;
              case 'mark_sent':
                if (po.status == 'draft') {
                  _updateStatus(po.id, 'sent');
                }
                break;
              case 'print':
                _printPO(po);
                break;
              case 'share_list':
                _shareAsShoppingList(po);
                break;
              case 'copy_text':
                _copyAsText(po);
                break;
              case 'email':
                _openEmailDialog(po);
                break;
              case 'pdf':
                _downloadPDF(po);
                break;
              case 'template':
                _showSaveTemplateDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            if (po.status == 'draft') ...[
              const PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(Icons.chat, size: 18),
                    SizedBox(width: 8),
                    Text('WhatsApp ke Supplier'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mark_sent',
                child: Row(
                  children: [
                    Icon(Icons.send, size: 18),
                    SizedBox(width: 8),
                    Text('Tandakan sebagai Dihantar'),
                  ],
                ),
              ),
            ],
            const PopupMenuItem(
              value: 'print',
              child: Row(
                children: [
                  Icon(Icons.print, size: 18),
                  SizedBox(width: 8),
                  Text('Cetak PO'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share_list',
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, size: 18),
                  SizedBox(width: 8),
                  Text('Kongsi sebagai Senarai Belian'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'copy_text',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 18),
                  SizedBox(width: 8),
                  Text('Salin sebagai Teks'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'email',
              child: Row(
                children: [
                  Icon(Icons.email, size: 18),
                  SizedBox(width: 8),
                  Text('Email'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, size: 18),
                  SizedBox(width: 8),
                  Text('Muat Turun PDF'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'template',
              child: Row(
                children: [
                  Icon(Icons.bookmark, size: 18),
                  SizedBox(width: 8),
                  Text('Simpan Template'),
                ],
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildReceiveDialog() {
    final po = _selectedPO!;
    
    return AlertDialog(
      title: const Text('Sahkan Penerimaan Barang'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('PO Number', po.poNumber),
          _buildInfoRow('Supplier', po.supplierName),
          _buildInfoRow('Jumlah', 'RM ${po.totalAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stok akan ditambah'),
                Text('Perbelanjaan akan direkod'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => _markAsReceived(po.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Sahkan Terima'),
        ),
      ],
    );
  }

  Widget _buildEmailDialog() {
    final po = _selectedPO!;
    
    return AlertDialog(
      title: const Text('Hantar PO melalui Email'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PO Number: ${po.poNumber}'),
                  Text('Jumlah: RM ${po.totalAmount.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailRecipientController,
              decoration: const InputDecoration(
                labelText: 'Email Supplier *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Supplier (Pilihan)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailMessageController,
              decoration: const InputDecoration(
                labelText: 'Mesej Tambahan (Pilihan)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _sendEmail,
          child: const Text('Hantar Email'),
        ),
      ],
    );
  }

  Widget _buildEditDialog() {
    final po = _selectedPO!;
    
    return AlertDialog(
      title: const Text('Edit Purchase Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PO Number: ${po.poNumber}'),
                  const Text('Status: Draft - Boleh dikemaskini'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Supplier Info
            const Text(
              'Maklumat Supplier',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editSupplierNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Supplier *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editSupplierPhoneController,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editSupplierEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editSupplierAddressController,
              decoration: const InputDecoration(
                labelText: 'Alamat Supplier',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editDeliveryAddressController,
              decoration: const InputDecoration(
                labelText: 'Alamat Penghantaran',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Payment & Delivery
            const Text(
              'Maklumat Pembayaran & Penghantaran',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editExpectedDeliveryController,
              decoration: const InputDecoration(
                labelText: 'Tarikh Jangka Penghantaran',
                border: OutlineInputBorder(),
                helperText: 'Bila nak terima barang?',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _editPaymentTermsController.text.isEmpty
                  ? '30 hari selepas penghantaran'
                  : _editPaymentTermsController.text,
              decoration: const InputDecoration(
                labelText: 'Terma Bayaran',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Cash on Delivery (COD)', child: Text('Cash on Delivery (COD)')),
                DropdownMenuItem(value: '7 hari selepas penghantaran', child: Text('7 hari selepas penghantaran')),
                DropdownMenuItem(value: '14 hari selepas penghantaran', child: Text('14 hari selepas penghantaran')),
                DropdownMenuItem(value: '30 hari selepas penghantaran', child: Text('30 hari selepas penghantaran')),
                DropdownMenuItem(value: '60 hari selepas penghantaran', child: Text('60 hari selepas penghantaran')),
                DropdownMenuItem(value: 'Bayaran Pendahuluan 50%', child: Text('Bayaran Pendahuluan 50%')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _editPaymentTermsController.text = value;
                }
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _editPaymentMethodController.text.isEmpty
                  ? 'Bank Transfer'
                  : _editPaymentMethodController.text,
              decoration: const InputDecoration(
                labelText: 'Cara Bayaran',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
                DropdownMenuItem(value: 'Cek', child: Text('Cek')),
                DropdownMenuItem(value: 'Online Banking', child: Text('Online Banking')),
                DropdownMenuItem(value: 'E-Wallet', child: Text('E-Wallet')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _editPaymentMethodController.text = value;
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editRequestedByController,
              decoration: const InputDecoration(
                labelText: 'Diminta Oleh',
                border: OutlineInputBorder(),
                helperText: 'Nama orang yang minta PO',
              ),
            ),
            const SizedBox(height: 16),
            
            // Financial Details
            const Text(
              'Maklumat Kewangan Tambahan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _editDiscountController,
                    decoration: const InputDecoration(
                      labelText: 'Diskaun (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _editShippingController,
                    decoration: const InputDecoration(
                      labelText: 'Kos Penghantaran (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _editTaxController,
                    decoration: const InputDecoration(
                      labelText: 'Cukai/SST (RM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Items List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Item Pesanan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _editItems.add({
                        'item_name': '',
                        'quantity': '1',
                        'unit': 'pcs',
                        'estimated_price': '0',
                        'notes': '',
                      });
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Item'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._editItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: TextEditingController(text: item['item_name']),
                              decoration: const InputDecoration(
                                labelText: 'Nama Item *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _editItems[index]['item_name'] = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: item['quantity']),
                              decoration: const InputDecoration(
                                labelText: 'Kuantiti *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  _editItems[index]['quantity'] = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: item['unit']),
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _editItems[index]['unit'] = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: item['estimated_price']),
                              decoration: const InputDecoration(
                                labelText: 'Harga (RM)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  _editItems[index]['estimated_price'] = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: item['notes']),
                              decoration: const InputDecoration(
                                labelText: 'Nota',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _editItems[index]['notes'] = value;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _editItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_editItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tiada item. Klik "Tambah Item" untuk tambah.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            
            // Total calculation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Jumlah Anggaran (dengan semua charges):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'RM ${(() {
                      double subtotal = 0.0;
                      for (var item in _editItems) {
                        final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
                        final price = double.tryParse(item['estimated_price']?.toString() ?? '0') ?? 0.0;
                        subtotal += qty * price;
                      }
                      final discount = double.tryParse(_editDiscountController.text) ?? 0.0;
                      final shipping = double.tryParse(_editShippingController.text) ?? 0.0;
                      final tax = double.tryParse(_editTaxController.text) ?? 0.0;
                      return (subtotal - discount + shipping + tax).toStringAsFixed(2);
                    })()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextField(
              controller: _editNotesController,
              decoration: const InputDecoration(
                labelText: 'Nota Tambahan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _updatePO,
          child: const Text('Simpan Perubahan'),
        ),
      ],
    );
  }

  Widget _buildSaveTemplateDialog() {
    return AlertDialog(
      title: const Text('Simpan sebagai Template'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Template membolehkan anda cipta PO baharu dengan item yang sama'),
          const SizedBox(height: 16),
          TextField(
            controller: _templateNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Template *',
              border: OutlineInputBorder(),
              hintText: 'Contoh: Pesanan Bulanan Supplier ABC',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _templateNameController.clear();
            });
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_templateNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nama diperlukan'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            
            // TODO: Implement save template
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template functionality coming soon')),
            );
            
            Navigator.pop(context);
            setState(() {
              _templateNameController.clear();
            });
          },
          child: const Text('Simpan Template'),
        ),
      ],
    );
  }

  Widget _buildTemplatesDialog() {
    return AlertDialog(
      title: const Text('PO Templates'),
      content: SizedBox(
        width: double.maxFinite,
        child: _templates.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Tiada template. Simpan PO sebagai template untuk kegunaan semula.'),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  return Card(
                    child: ListTile(
                      title: Text(template['template_name'] ?? 'Unknown'),
                      subtitle: Text(template['supplier_name'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.description),
                            onPressed: () {
                              // TODO: Create PO from template
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Template functionality coming soon')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // TODO: Delete template
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Template functionality coming soon')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildDuplicateDialog() {
    final po = _selectedPO!;
    
    return AlertDialog(
      title: const Text('Duplikasi Purchase Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PO Asal: ${po.poNumber}'),
                Text('Supplier: ${po.supplierName}'),
                Text('Jumlah: RM ${po.totalAmount.toStringAsFixed(2)}'),
                Text('Items: ${po.items.length} item'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ℹ️ PO baharu akan dicipta sebagai Draft dengan maklumat supplier dan items yang sama. Anda boleh edit sebelum menghantar.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _selectedPO = null);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => _duplicatePO(po.id),
          child: const Text('Duplikasi PO'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

