import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/business_profile_error_handler.dart';
import '../../../data/repositories/consignment_payments_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/consignment_payment.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Simplified Payment Recording Page
/// Step-by-step flow for recording vendor payments (non-technical user friendly)
class CreatePaymentSimplifiedPage extends StatefulWidget {
  const CreatePaymentSimplifiedPage({super.key});

  @override
  State<CreatePaymentSimplifiedPage> createState() => _CreatePaymentSimplifiedPageState();
}

class _CreatePaymentSimplifiedPageState extends State<CreatePaymentSimplifiedPage> {
  final _paymentsRepo = ConsignmentPaymentsRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();

  // Step management
  int _currentStep = 1;
  final int _totalSteps = 4;
  bool _hasOutstandingClaims = false; // Track if vendor has outstanding claims

  // Data
  List<Vendor> _vendors = [];
  String? _selectedVendorId;
  Vendor? _selectedVendor;
  OutstandingBalance? _outstandingBalance;
  List<OutstandingClaim> _selectedClaims = [];
  PaymentMethod _selectedPaymentMethod = PaymentMethod.perClaim;
  DateTime _paymentDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // UI State
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);
      if (mounted) {
        setState(() {
          _vendors = vendors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat memuatkan vendor: $e');
      }
    }
  }

  Future<void> _loadOutstandingBalance() async {
    if (_selectedVendorId == null) return;

    setState(() => _isLoading = true);
    try {
      final balance = await _paymentsRepo.getOutstandingBalance(_selectedVendorId!);
      if (mounted) {
        setState(() {
          _outstandingBalance = balance;
          _hasOutstandingClaims = balance.claims.isNotEmpty && balance.totalOutstanding > 0;
          _selectedClaims = [];
          // If no outstanding claims, skip to payment details step
          if (!_hasOutstandingClaims && _currentStep == 1) {
            _selectedPaymentMethod = PaymentMethod.carryForward; // Default for manual payment
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show error, just mark as no outstanding claims
        _hasOutstandingClaims = false;
        _outstandingBalance = OutstandingBalance(
          totalOutstanding: 0.0,
          claims: [],
        );
      }
    }
  }

  void _onVendorSelected(String? vendorId) {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedVendor = vendorId != null
          ? _vendors.firstWhere((v) => v.id == vendorId, orElse: () => _vendors.first)
          : null;
      _outstandingBalance = null;
      _hasOutstandingClaims = false;
      _selectedClaims = [];
      _amountController.clear();
    });
    if (vendorId != null) {
      _loadOutstandingBalance();
    }
  }

  void _onPaymentMethodChanged(PaymentMethod? method) {
    if (method == null) return;
    setState(() {
      _selectedPaymentMethod = method;
      _selectedClaims = [];
      _amountController.clear();
    });
  }

  void _toggleClaimSelection(OutstandingClaim claim) {
    setState(() {
      if (_selectedClaims.any((c) => c.claimId == claim.claimId)) {
        _selectedClaims.removeWhere((c) => c.claimId == claim.claimId);
      } else {
        _selectedClaims.add(claim);
      }
      _updateAmountFromSelectedClaims();
    });
  }

  void _updateAmountFromSelectedClaims() {
    if (_selectedPaymentMethod == PaymentMethod.billToBill) {
      // Sum all selected claims
      final total = _selectedClaims.fold<double>(
        0.0,
        (sum, claim) => sum + claim.balanceAmount,
      );
      _amountController.text = total.toStringAsFixed(2);
    } else if (_selectedClaims.isNotEmpty) {
      // Single claim - use its balance
      _amountController.text = _selectedClaims.first.balanceAmount.toStringAsFixed(2);
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      // Validate current step before proceeding
      if (_validateCurrentStep()) {
        setState(() {
          // Skip step 2 if no outstanding claims
          if (_currentStep == 1 && !_hasOutstandingClaims) {
            _currentStep = 3; // Skip to payment details
          } else {
            _currentStep++;
          }
        });
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        // If on step 3 and no outstanding claims, go back to step 1 (skip step 2)
        if (_currentStep == 3 && !_hasOutstandingClaims) {
          _currentStep = 1;
        } else {
          _currentStep--;
        }
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1: // Vendor selection
        if (_selectedVendorId == null) {
          _showError('Sila pilih vendor terlebih dahulu');
          return false;
        }
        // Allow proceed even if no outstanding claims (for advance payment)
        return true;

      case 2: // Claim selection (optional if no outstanding claims)
        // If no outstanding claims, skip this step
        if (!_hasOutstandingClaims) {
          return true; // Allow proceed without claims
        }
        // If has claims but none selected, validate based on payment method
        if (_selectedPaymentMethod != PaymentMethod.carryForward && _selectedClaims.isEmpty) {
          _showError('Sila pilih sekurang-kurangnya satu tuntutan');
          return false;
        }
        return true;

      case 3: // Payment details
        final amount = double.tryParse(_amountController.text);
        if (amount == null || amount <= 0) {
          _showError('Sila masukkan jumlah bayaran yang sah');
          return false;
        }
        // Only validate against claims if claims are selected
        if (_selectedClaims.isNotEmpty) {
          final maxAmount = _selectedClaims.fold<double>(
            0.0,
            (sum, claim) => sum + claim.balanceAmount,
          );
          if (amount > maxAmount) {
            _showError('Jumlah bayaran tidak boleh melebihi jumlah baki tertunggak (RM ${maxAmount.toStringAsFixed(2)})');
            return false;
          }
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> _createPayment() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isCreating = true);

    try {
      final amount = double.parse(_amountController.text);

      // Only include claim IDs if claims are selected
      final List<String>? claimIds = _selectedClaims.isNotEmpty && _selectedPaymentMethod == PaymentMethod.billToBill
          ? _selectedClaims.map((c) => c.claimId).toList()
          : null;
      
      final String? claimId = _selectedClaims.isNotEmpty &&
              (_selectedPaymentMethod == PaymentMethod.perClaim ||
               _selectedPaymentMethod == PaymentMethod.partial)
          ? _selectedClaims.first.claimId
          : null;

      final payment = await _paymentsRepo.createPayment(
        vendorId: _selectedVendorId!,
        paymentMethod: _selectedPaymentMethod,
        paymentDate: _paymentDate,
        totalAmount: amount,
        claimIds: claimIds,
        claimId: claimId,
        paymentReference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        setState(() => _isCreating = false);
        _showSuccess('✅ Bayaran berjaya direkodkan!\nNo. Bayaran: ${payment.paymentNumber}');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, payment);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        
        // Handle subscription enforcement errors
        final subscriptionHandled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Rekod Bayaran',
          error: e,
        );
        if (subscriptionHandled) return;
        
        // Handle duplicate key error (profile not setup)
        final duplicateKeyHandled = await BusinessProfileErrorHandler.handleDuplicateKeyError(
          context: context,
          error: e,
          actionName: 'Rekod Bayaran',
        );
        if (duplicateKeyHandled) return;
        
        _showError('Ralat mencipta bayaran. Sila cuba lagi.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rekod Bayaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),

          // Step Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildStepContent(),
                  ),
          ),

          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final stepNum = index + 1;
          final isActive = stepNum == _currentStep;
          final isCompleted = stepNum < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? AppColors.primary
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : isActive
                            ? AppColors.primary
                            : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '$stepNum',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                if (stepNum < _totalSteps)
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1VendorSelection();
      case 2:
        return _buildStep2ClaimSelection();
      case 3:
        return _buildStep3PaymentDetails();
      case 4:
        return _buildStep4Review();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1VendorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 1: Pilih Vendor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih vendor yang membuat bayaran',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vendor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                  value: _selectedVendorId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Vendor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  isExpanded: true,
                  items: _vendors.map((vendor) {
                    return DropdownMenuItem(
                      value: vendor.id,
                      child: Text(
                        vendor.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onVendorSelected,
                ),
                if (_outstandingBalance != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Baki Tertunggak',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'RM ${_outstandingBalance!.totalOutstanding.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_outstandingBalance!.claims.length} tuntutan tertunggak',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2ClaimSelection() {
    // If no outstanding claims, show info and allow proceed
    if (!_hasOutstandingClaims || _outstandingBalance == null || _outstandingBalance!.claims.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Langkah 2: Pilih Tuntutan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tiada tuntutan tertunggak untuk vendor ini',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Anda boleh teruskan untuk rekod bayaran tanpa memilih tuntutan (contoh: advance payment atau bayaran manual).',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 2: Pilih Tuntutan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedPaymentMethod == PaymentMethod.billToBill
              ? 'Pilih tuntutan yang ingin dibayar (boleh pilih beberapa)'
              : 'Pilih satu tuntutan untuk dibayar',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kaedah Bayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentMethod>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Kaedah',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    if (_hasOutstandingClaims) ...[
                      const DropdownMenuItem(
                        value: PaymentMethod.perClaim,
                        child: Text('Per Claim (Bayar satu tuntutan penuh)'),
                      ),
                      const DropdownMenuItem(
                        value: PaymentMethod.partial,
                        child: Text('Partial (Bayar separa untuk satu tuntutan)'),
                      ),
                      const DropdownMenuItem(
                        value: PaymentMethod.billToBill,
                        child: Text('Bill to Bill (Bayar beberapa tuntutan)'),
                      ),
                    ],
                    const DropdownMenuItem(
                      value: PaymentMethod.carryForward,
                      child: Text('Manual Payment (Bayaran tanpa tuntutan)'),
                    ),
                  ],
                  onChanged: _onPaymentMethodChanged,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Senarai Tuntutan Tertunggak',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._outstandingBalance!.claims.map((claim) {
                  final isSelected = _selectedClaims.any((c) => c.claimId == claim.claimId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                    child: ListTile(
                      title: Text(
                        claim.claimNumber,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Baki: RM ${claim.balanceAmount.toStringAsFixed(2)}',
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () {
                        if (_selectedPaymentMethod == PaymentMethod.billToBill) {
                          _toggleClaimSelection(claim);
                        } else {
                          // Single selection
                          setState(() {
                            _selectedClaims = [claim];
                            _updateAmountFromSelectedClaims();
                          });
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3PaymentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 3: Butiran Bayaran',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isi maklumat bayaran',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tarikh Bayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() => _paymentDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy', 'ms_MY').format(_paymentDate),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Jumlah Bayaran (RM)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    border: OutlineInputBorder(),
                    prefixText: 'RM ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (_selectedClaims.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Jumlah maksimum: RM ${_selectedClaims.fold<double>(0.0, (sum, c) => sum + c.balanceAmount).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Rujukan Bayaran (Pilihan)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'No. cek, transfer, dll.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nota (Pilihan)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Masukkan nota jika perlu...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Review() {
    final totalSelected = _selectedClaims.fold<double>(
      0.0,
      (sum, claim) => sum + claim.balanceAmount,
    );
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 4: Semak & Sahkan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sila semak maklumat sebelum mengesahkan',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Vendor', _selectedVendor?.name ?? '-'),
                const Divider(),
                _buildReviewRow('Kaedah Bayaran', _getPaymentMethodLabel(_selectedPaymentMethod)),
                const Divider(),
                _buildReviewRow('Tarikh Bayaran', DateFormat('dd MMMM yyyy', 'ms_MY').format(_paymentDate)),
                const Divider(),
                _buildReviewRow('Jumlah Bayaran', 'RM ${amount.toStringAsFixed(2)}'),
                if (_referenceController.text.isNotEmpty) ...[
                  const Divider(),
                  _buildReviewRow('Rujukan', _referenceController.text),
                ],
                if (_notesController.text.isNotEmpty) ...[
                  const Divider(),
                  _buildReviewRow('Nota', _notesController.text),
                ],
                if (_selectedClaims.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tuntutan yang Dibayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._selectedClaims.map((claim) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(claim.claimNumber),
                          Text(
                            'RM ${claim.balanceAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jumlah Tuntutan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'RM ${totalSelected.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bayaran ini tidak dikaitkan dengan tuntutan tertentu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.perClaim:
        return 'Per Claim';
      case PaymentMethod.partial:
        return 'Partial';
      case PaymentMethod.billToBill:
        return 'Bill to Bill';
      case PaymentMethod.carryForward:
        return 'Carry Forward';
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Kembali'),
              ),
            ),
          if (_currentStep > 1) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 1 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _isCreating
                  ? null
                  : (_currentStep < _totalSteps ? _nextStep : _createPayment),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep < _totalSteps ? 'Seterusnya' : 'Sahkan Bayaran',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

