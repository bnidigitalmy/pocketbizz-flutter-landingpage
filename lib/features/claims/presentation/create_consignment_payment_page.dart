import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/consignment_payments_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/consignment_payment.dart';
import '../../../data/models/consignment_claim.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Create Consignment Payment Page
/// Vendor makes payment to user with different payment methods
class CreateConsignmentPaymentPage extends StatefulWidget {
  const CreateConsignmentPaymentPage({super.key});

  @override
  State<CreateConsignmentPaymentPage> createState() => _CreateConsignmentPaymentPageState();
}

class _CreateConsignmentPaymentPageState extends State<CreateConsignmentPaymentPage> {
  final _paymentsRepo = ConsignmentPaymentsRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();

  List<Vendor> _vendors = [];
  String? _selectedVendorId;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.perClaim;
  DateTime _paymentDate = DateTime.now();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // For per_claim and partial
  String? _selectedClaimId;
  
  // For bill_to_bill
  List<String> _selectedClaimIds = [];
  
  bool _isLoading = false;
  bool _isCreating = false;
  OutstandingBalance? _outstandingBalance;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vendors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadOutstandingBalance() async {
    if (_selectedVendorId == null) return;

    try {
      final balance = await _paymentsRepo.getOutstandingBalance(_selectedVendorId!);
      if (mounted) {
        setState(() {
          _outstandingBalance = balance;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading outstanding balance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVendorSelected(String? vendorId) {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedClaimId = null;
      _selectedClaimIds = [];
      _outstandingBalance = null;
    });
    if (vendorId != null) {
      _loadOutstandingBalance();
    }
  }

  void _onPaymentMethodChanged(PaymentMethod? method) {
    if (method == null) return;
    setState(() {
      _selectedPaymentMethod = method;
      _selectedClaimId = null;
      _selectedClaimIds = [];
    });
  }

  Future<void> _createPayment() async {
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih vendor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila masukkan jumlah bayaran yang sah'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate based on payment method
    if (_selectedPaymentMethod == PaymentMethod.perClaim || 
        _selectedPaymentMethod == PaymentMethod.partial) {
      if (_selectedClaimId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sila pilih tuntutan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_selectedPaymentMethod == PaymentMethod.billToBill) {
      if (_selectedClaimIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sila pilih sekurang-kurangnya satu tuntutan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      final payment = await _paymentsRepo.createPayment(
        vendorId: _selectedVendorId!,
        paymentMethod: _selectedPaymentMethod,
        paymentDate: _paymentDate,
        totalAmount: amount,
        claimIds: _selectedPaymentMethod == PaymentMethod.billToBill ? _selectedClaimIds : null,
        claimId: (_selectedPaymentMethod == PaymentMethod.perClaim || 
                 _selectedPaymentMethod == PaymentMethod.partial) 
            ? _selectedClaimId 
            : null,
        paymentReference: _referenceController.text.isEmpty 
            ? null 
            : _referenceController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bayaran berjaya direkodkan!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, payment);
      }
    } catch (e) {
      if (mounted) {
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Rekod Bayaran Konsainan',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal rekod: Sila cuba lagi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vendor Selection
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
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedVendorId,
                            decoration: const InputDecoration(
                              labelText: 'Pilih Vendor',
                              border: OutlineInputBorder(),
                            ),
                            items: _vendors.map((vendor) {
                              return DropdownMenuItem(
                                value: vendor.id,
                                child: Text(vendor.name),
                              );
                            }).toList(),
                            onChanged: _onVendorSelected,
                          ),
                          if (_outstandingBalance != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Baki Tertunggak:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'RM ${_outstandingBalance!.totalOutstanding.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    '${_outstandingBalance!.claims.length} tuntutan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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

                  const SizedBox(height: 16),

                  // Payment Method
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
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PaymentMethod>(
                            value: _selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Pilih Kaedah',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: PaymentMethod.billToBill,
                                child: Text('Bill to Bill (Bayaran untuk beberapa tuntutan)'),
                              ),
                              DropdownMenuItem(
                                value: PaymentMethod.perClaim,
                                child: Text('Per Claim (Bayaran untuk satu tuntutan penuh)'),
                              ),
                              DropdownMenuItem(
                                value: PaymentMethod.partial,
                                child: Text('Partial (Bayaran separa untuk satu tuntutan)'),
                              ),
                              DropdownMenuItem(
                                value: PaymentMethod.carryForward,
                                child: Text('Carry Forward (Bawa ke hadapan)'),
                              ),
                            ],
                            onChanged: _onPaymentMethodChanged,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Date
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
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _paymentDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jumlah Bayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'RM',
                              border: OutlineInputBorder(),
                              prefixText: 'RM ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Claim Selection (for per_claim, partial, bill_to_bill)
                  if (_selectedVendorId != null && 
                      (_selectedPaymentMethod == PaymentMethod.perClaim ||
                       _selectedPaymentMethod == PaymentMethod.partial ||
                       _selectedPaymentMethod == PaymentMethod.billToBill) &&
                      _outstandingBalance != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPaymentMethod == PaymentMethod.billToBill
                                  ? 'Pilih Tuntutan (Boleh pilih beberapa)'
                                  : 'Pilih Tuntutan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_outstandingBalance!.claims.isEmpty)
                              const Text(
                                'Tiada tuntutan tertunggak',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              ..._outstandingBalance!.claims.map((claim) {
                                final isSelected = _selectedPaymentMethod == PaymentMethod.billToBill
                                    ? _selectedClaimIds.contains(claim.claimId)
                                    : _selectedClaimId == claim.claimId;

                                return ListTile(
                                  title: Text(claim.claimNumber),
                                  subtitle: Text(
                                    'Baki: RM ${claim.balanceAmount.toStringAsFixed(2)}',
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                                      : const Icon(Icons.radio_button_unchecked),
                                  onTap: () {
                                    setState(() {
                                      if (_selectedPaymentMethod == PaymentMethod.billToBill) {
                                        if (isSelected) {
                                          _selectedClaimIds.remove(claim.claimId);
                                        } else {
                                          _selectedClaimIds.add(claim.claimId);
                                        }
                                      } else {
                                        _selectedClaimId = claim.claimId;
                                        // Auto-fill amount with balance
                                        _amountController.text = 
                                            claim.balanceAmount.toStringAsFixed(2);
                                      }
                                    });
                                  },
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment Reference
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rujukan Bayaran (Pilihan)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _referenceController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'No. cek, transfer, dll.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nota (Pilihan)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Masukkan nota jika perlu...',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
                          : const Text(
                              'Rekod Bayaran',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}



