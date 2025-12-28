import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/consignment_payments_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/consignment_claim.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Record Payment Page
/// Simple flow: Select vendor → Select claim → Enter amount received → Update claim
class RecordPaymentPage extends StatefulWidget {
  const RecordPaymentPage({
    super.key,
    this.initialVendorId,
    this.initialClaimId,
  });

  /// Optional: preselect vendor and claim when opened from Claim Detail
  final String? initialVendorId;
  final String? initialClaimId;

  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();
  final _paymentsRepo = ConsignmentPaymentsRepositorySupabase();

  // Step management
  int _currentStep = 1;
  final int _totalSteps = 3;

  // Data
  List<Vendor> _vendors = [];
  String? _selectedVendorId;
  Vendor? _selectedVendor;
  List<ConsignmentClaim> _claims = [];
  ConsignmentClaim? _selectedClaim;
  List<Map<String, dynamic>> _claimPayments = [];
  DateTime _paymentDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // UI State
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
    // If opened with preselected vendor/claim, try to prefill after vendors are loaded
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

        // Prefill selection if arguments were provided
        if (widget.initialVendorId != null) {
          _prefillVendorAndClaim();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat memuatkan vendor: $e');
      }
    }
  }

  Future<void> _prefillVendorAndClaim() async {
    final vendorId = widget.initialVendorId;
    if (vendorId == null) return;

    // Set vendor selection
    setState(() {
      _selectedVendorId = vendorId;
      _selectedVendor = _vendors.firstWhere(
        (v) => v.id == vendorId,
        orElse: () => _vendors.first,
      );
    });

    // Load claims and preselect claim if provided
    await _loadClaims(preselectClaimId: widget.initialClaimId);
  }

  Future<void> _loadClaims({String? preselectClaimId}) async {
    if (_selectedVendorId == null) return;

    setState(() => _isLoading = true);
    try {
      final claims = await _claimsRepo.getClaimsByVendor(_selectedVendorId!);
      // Filter claims with outstanding balance and not settled/rejected
      final outstandingClaims = claims.where((c) {
        final hasBalance = c.balanceAmount > 0;
        final allowStatus = c.status != ClaimStatus.settled && c.status != ClaimStatus.rejected;
        return hasBalance && allowStatus;
      }).toList();
      
      // Load full claim details with items for each claim
      final claimsWithDetails = <ConsignmentClaim>[];
      for (var claim in outstandingClaims) {
        try {
          final fullClaim = await _claimsRepo.getClaimById(claim.id);
          claimsWithDetails.add(fullClaim);
        } catch (e) {
          // If error loading details, use basic claim
          claimsWithDetails.add(claim);
        }
      }
      
      if (mounted) {
        setState(() {
          _claims = claimsWithDetails;
          _selectedClaim = null;
          _amountController.clear();
          _isLoading = false;
        });

        // If a claimId is provided (from Claim Detail), preselect it
        if (preselectClaimId != null) {
          final match = claimsWithDetails.where((c) => c.id == preselectClaimId).toList();
          if (match.isNotEmpty) {
            _onClaimSelected(match.first);
            // Jump to step 2 (Payment Details) since selection is done
            setState(() {
              _currentStep = 2;
            });
          }
        }

        // If still empty, log summary for debugging
        if (_claims.isEmpty) {
          final statusCounts = <String, int>{};
          for (final c in claims) {
            statusCounts[c.status.toString()] = (statusCounts[c.status.toString()] ?? 0) + 1;
          }
          debugPrint('No outstanding claims. Status summary: $statusCounts');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Ralat memuatkan tuntutan: $e');
      }
    }
  }

  void _onVendorSelected(String? vendorId) {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedVendor = vendorId != null
          ? _vendors.firstWhere((v) => v.id == vendorId, orElse: () => _vendors.first)
          : null;
      _claims = [];
      _selectedClaim = null;
      _amountController.clear();
    });
    if (vendorId != null) {
      _loadClaims();
    }
  }

  void _onClaimSelected(ConsignmentClaim? claim) async {
    if (claim == null) {
      setState(() {
        _selectedClaim = null;
        _amountController.clear();
        _claimPayments = [];
      });
      return;
    }

    // Load full claim details with items
    setState(() => _isLoading = true);
    try {
      final fullClaim = await _claimsRepo.getClaimById(claim.id);
      final payments = await _paymentsRepo.getPaymentsByClaim(claim.id);
      if (mounted) {
        setState(() {
          _selectedClaim = fullClaim;
          // Auto-fill with remaining balance
          _amountController.text = fullClaim.balanceAmount.toStringAsFixed(2);
          _claimPayments = payments;
          _isLoading = false;
          // If coming from preselect flow, move to step 2 automatically
          if (widget.initialClaimId != null && widget.initialClaimId == claim.id) {
            _currentStep = 2;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedClaim = claim; // Use basic claim if error
          _amountController.text = claim.balanceAmount.toStringAsFixed(2);
          _claimPayments = [];
          _isLoading = false;
        });
        _showError('Ralat memuatkan butiran tuntutan: $e');
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1: // Vendor & Claim selection
        if (_selectedVendorId == null) {
          _showError('Sila pilih vendor terlebih dahulu');
          return false;
        }
        if (_selectedClaim == null) {
          _showError('Sila pilih tuntutan terlebih dahulu');
          return false;
        }
        return true;

      case 2: // Payment details
        final amount = double.tryParse(_amountController.text);
        if (amount == null || amount <= 0) {
          _showError('Sila masukkan jumlah bayaran yang sah');
          return false;
        }
        if (_selectedClaim != null && amount > _selectedClaim!.balanceAmount) {
          _showError('Jumlah bayaran tidak boleh melebihi baki tertunggak (RM ${_selectedClaim!.balanceAmount.toStringAsFixed(2)})');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> _savePayment() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text);

      // Rekod payment entry + allocation (trigger DB akan auto update claim paid/balance/status)
      await _paymentsRepo.recordPaymentForClaim(
        claimId: _selectedClaim!.id,
        vendorId: _selectedClaim!.vendorId,
        amount: amount,
        paymentDate: _paymentDate,
        paymentReference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        _showSuccess('✅ Bayaran berjaya direkodkan!\nNo. Tuntutan: ${_selectedClaim!.claimNumber}');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Rekod Bayaran',
          error: e,
        );
        if (handled) return;
        _showError('Ralat: Sila cuba lagi');
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
        return _buildStep1SelectClaim();
      case 2:
        return _buildStep2PaymentDetails();
      case 3:
        return _buildStep3Review();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1SelectClaim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 1: Pilih Vendor & Tuntutan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih vendor dan tuntutan yang telah menerima bayaran',
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
                if (_claims.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Tuntutan Tertunggak',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._claims.map((claim) {
                    final isSelected = _selectedClaim?.id == claim.id;
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tarikh: ${DateFormat('dd MMM yyyy').format(claim.claimDate)}'),
                            if (claim.items != null && claim.items!.isNotEmpty) ...[
                              Text(
                                'Invoice: ${claim.items!.map((item) => item.deliveryNumber ?? '-').toSet().join(', ')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            Text('Jumlah Tuntutan: RM ${claim.netAmount.toStringAsFixed(2)}'),
                            Text('Telah Dibayar: RM ${claim.paidAmount.toStringAsFixed(2)}'),
                            Text(
                              'Baki Tertunggak: RM ${claim.balanceAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: AppColors.primary)
                            : const Icon(Icons.radio_button_unchecked),
                        onTap: () => _onClaimSelected(claim),
                      ),
                    );
                  }),
                ] else if (_selectedVendorId != null && !_isLoading) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tiada tuntutan tertunggak untuk vendor ini',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[900],
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

  Widget _buildStep2PaymentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 2: Butiran Bayaran',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Isi maklumat bayaran yang diterima',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedClaim != null) ...[
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tuntutan: ${_selectedClaim!.claimNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedClaim!.items != null && _selectedClaim!.items!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Invoice Penghantaran:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._selectedClaim!.items!.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.receipt, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${item.deliveryNumber ?? '-'} - ${item.productName} (${item.quantitySold.toStringAsFixed(2)} unit)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jumlah Tuntutan:', style: TextStyle(color: Colors.grey[700])),
                      Text(
                        'RM ${_selectedClaim!.netAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Telah Dibayar:', style: TextStyle(color: Colors.grey[700])),
                      Text(
                        'RM ${_selectedClaim!.paidAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Baki Tertunggak:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      Text(
                        'RM ${_selectedClaim!.balanceAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_claimPayments.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sejarah Bayaran untuk Tuntutan Ini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._claimPayments.map((p) {
                      final date = DateTime.parse(p['payment_date'] as String);
                      final paymentNumber = p['payment_number'] as String? ?? '-';
                      final ref = p['payment_reference'] as String?;
                      final allocated = (p['allocated_amount'] as num?)?.toDouble() ?? 0.0;
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments),
                            title: Text(paymentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(date)),
                                Text('Diperuntuk: RM ${allocated.toStringAsFixed(2)}'),
                                if (ref != null && ref.isNotEmpty) Text('Rujukan: $ref'),
                              ],
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
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
                  'Jumlah Bayaran Diterima (RM)',
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _selectedClaim == null
                          ? null
                          : () {
                              _amountController.text = _selectedClaim!.balanceAmount.toStringAsFixed(2);
                              setState(() {});
                            },
                      child: const Text('Bayar Penuh'),
                    ),
                    OutlinedButton(
                      onPressed: _selectedClaim == null
                          ? null
                          : () {
                              final half = (_selectedClaim!.balanceAmount / 2).clamp(0, _selectedClaim!.balanceAmount);
                              _amountController.text = half.toStringAsFixed(2);
                              setState(() {});
                            },
                      child: const Text('50%'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        _amountController.clear();
                        setState(() {});
                      },
                      child: const Text('Kosongkan'),
                    ),
                  ],
                ),
                if (_selectedClaim != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Maksimum: RM ${_selectedClaim!.balanceAmount.toStringAsFixed(2)}',
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

  Widget _buildStep3Review() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remainingBalance = _selectedClaim != null
        ? _selectedClaim!.balanceAmount - amount
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Langkah 3: Semak & Sahkan',
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
                _buildReviewRow('No. Tuntutan', _selectedClaim?.claimNumber ?? '-'),
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
                if (_selectedClaim != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildReviewRow('Jumlah Tuntutan', 'RM ${_selectedClaim!.netAmount.toStringAsFixed(2)}'),
                  _buildReviewRow('Telah Dibayar (Sebelum)', 'RM ${_selectedClaim!.paidAmount.toStringAsFixed(2)}'),
                  _buildReviewRow('Bayaran Baru', 'RM ${amount.toStringAsFixed(2)}'),
                  _buildReviewRow('Telah Dibayar (Selepas)', 'RM ${(_selectedClaim!.paidAmount + amount).toStringAsFixed(2)}'),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Baki Tertunggak (Selepas)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: remainingBalance > 0 ? Colors.orange : AppColors.success,
                        ),
                      ),
                      Text(
                        'RM ${remainingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: remainingBalance > 0 ? Colors.orange : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (remainingBalance == 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tuntutan ini akan ditandakan sebagai "Settled" selepas bayaran direkodkan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
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
              onPressed: _isSaving
                  ? null
                  : (_currentStep < _totalSteps ? _nextStep : _savePayment),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _currentStep < _totalSteps ? 'Seterusnya' : 'Sahkan & Simpan',
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

