import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../services/subscription_service.dart';

/// Admin User Management Page
/// Manage users, subscriptions, passwords, and account status
class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  Map<String, dynamic>? _selectedUser;

  // Dialog states
  bool _showManageDialog = false;
  bool _showResetPasswordDialog = false;
  bool _showDeleteDialog = false;
  bool _showSuspendDialog = false;
  bool _showChangePlanDialog = false;
  bool _showAddPaymentDialog = false;

  // Form states
  String _tempPassword = '';
  bool _copiedPassword = false;
  String _selectedPlan = '';
  String _durationMonths = '1';
  String _paymentAmount = '';
  String _paymentMethod = 'manual';
  String _paymentNotes = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      // Try to call Edge Function to get users list
      try {
        final response = await supabase.functions.invoke('admin-users', body: {
          'action': 'list',
        });

        if (response.data != null && response.data['users'] != null) {
          final authUsers = (response.data['users'] as List);
          
          // Fetch subscription data for all users
          final usersList = <Map<String, dynamic>>[];
          
          for (final user in authUsers) {
            final userId = user['id'] as String;
            
            // Get latest subscription for this user with plan info
            final subResponse = await supabase
                .from('subscriptions')
                .select('status, expires_at, duration_months, subscription_plans(name)')
                .eq('user_id', userId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            
            // Extract plan name from joined data
            final planName = subResponse?['subscription_plans']?['name'] as String? ?? 'PocketBizz';
            
            // Check early adopter status
            final earlyAdopterResponse = await supabase
                .from('early_adopters')
                .select('registration_number')
                .eq('user_id', userId)
                .maybeSingle();
            
            usersList.add({
              'id': userId,
              'email': user['email'] ?? '${userId.substring(0, 8)}...',
              'name': user['user_metadata']?['full_name'] ?? 
                      user['user_metadata']?['name'] ?? 
                      'User',
              'businessName': user['user_metadata']?['business_name'],
              'created_at': user['created_at'],
              'suspended': user['banned_until'] != null,
              'plan': planName,
              'status': _getStatusLabel(subResponse),
              'expiresAt': subResponse?['expires_at'],
              'isEarlyAdopter': earlyAdopterResponse != null,
              'earlyAdopterNumber': earlyAdopterResponse?['registration_number'],
            });
          }

          if (mounted) {
            setState(() {
              _users = usersList;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        // Fallback if Edge Function fails
        debugPrint('Edge Function failed, using fallback: $e');
      }

      // Fallback: get from subscriptions with more data
      final response = await supabase
          .from('subscriptions')
          .select('user_id, created_at, status, expires_at, duration_months, subscription_plans(name)')
          .order('created_at', ascending: false)
          .limit(1000);
      
      final userIds = <String>{};
      final usersList = <Map<String, dynamic>>[];
      
      for (final sub in response as List) {
        final subData = sub as Map<String, dynamic>;
        final userId = subData['user_id'] as String;
        if (!userIds.contains(userId)) {
          userIds.add(userId);
          
          // Extract plan name from joined data
          final fallbackPlanName = subData['subscription_plans']?['name'] as String? ?? 'PocketBizz';
          
          // Check early adopter status
          final earlyAdopterResponse = await supabase
              .from('early_adopters')
              .select('registration_number')
              .eq('user_id', userId)
              .maybeSingle();
          
          usersList.add({
            'id': userId,
            'email': '${userId.substring(0, 8)}...@user',
            'name': 'User ${userId.substring(0, 6)}',
            'businessName': null,
            'created_at': subData['created_at'],
            'suspended': false,
            'plan': fallbackPlanName,
            'status': _getStatusLabel(subData),
            'expiresAt': subData['expires_at'],
            'isEarlyAdopter': earlyAdopterResponse != null,
            'earlyAdopterNumber': earlyAdopterResponse?['registration_number'],
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _users = usersList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  String _getStatusLabel(Map<String, dynamic>? subscription) {
    if (subscription == null) return 'No Subscription';
    
    final status = subscription['status'] as String?;
    final expiresAt = subscription['expires_at'] as String?;
    
    if (expiresAt != null) {
      final expiryDate = DateTime.parse(expiresAt);
      if (expiryDate.isBefore(DateTime.now())) {
        return 'Expired';
      }
    }
    
    switch (status) {
      case 'active':
        return 'Active';
      case 'trial':
        return 'Trial';
      case 'expired':
        return 'Expired';
      case 'grace':
        return 'Grace Period';
      case 'paused':
        return 'Paused';
      case 'cancelled':
        return 'Cancelled';
      case 'pending_payment':
        return 'Pending Payment';
      default:
        return status ?? 'Unknown';
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bgColor;
    
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green[800]!;
        bgColor = Colors.green[100]!;
        break;
      case 'trial':
        color = Colors.blue[800]!;
        bgColor = Colors.blue[100]!;
        break;
      case 'expired':
        color = Colors.red[800]!;
        bgColor = Colors.red[100]!;
        break;
      case 'grace period':
        color = Colors.orange[800]!;
        bgColor = Colors.orange[100]!;
        break;
      case 'paused':
        color = Colors.purple[800]!;
        bgColor = Colors.purple[100]!;
        break;
      case 'cancelled':
        color = Colors.grey[800]!;
        bgColor = Colors.grey[200]!;
        break;
      case 'pending payment':
        color = Colors.amber[800]!;
        bgColor = Colors.amber[100]!;
        break;
      default:
        color = Colors.grey[600]!;
        bgColor = Colors.grey[100]!;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      return (user['email'] as String).toLowerCase().contains(query) ||
          (user['name'] as String).toLowerCase().contains(query);
    }).toList();
  }

  void _handleAction(String action, Map<String, dynamic> user) {
    setState(() => _selectedUser = user);
    
    switch (action) {
      case 'manage':
        setState(() => _showManageDialog = true);
        break;
      case 'reset_password':
        setState(() => _showResetPasswordDialog = true);
        break;
      case 'change_plan':
        setState(() => _showChangePlanDialog = true);
        break;
      case 'add_payment':
        setState(() => _showAddPaymentDialog = true);
        break;
      case 'suspend':
        setState(() => _showSuspendDialog = true);
        break;
      case 'delete':
        setState(() => _showDeleteDialog = true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadUsers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari email, nama, atau business name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                
                // Users table
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 400,
                    maxHeight: MediaQuery.of(context).size.height - 250,
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? const Center(child: Text('Tiada pengguna dijumpai'))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                    columnSpacing: 24,
                                    headingRowHeight: 48,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 72,
                                    columns: const [
                                      DataColumn(
                                        label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Business', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                      DataColumn(
                                        label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                                        numeric: false,
                                      ),
                                    ],
                              rows: _filteredUsers.map((user) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 200),
                                        child: Text(
                                          user['email'] as String,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          user['name'] as String,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          (user['businessName'] as String?) ?? '-',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 120),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              user['plan'] as String? ?? '-',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            if (user['isEarlyAdopter'] == true) ...[
                                              const SizedBox(width: 4),
                                              Tooltip(
                                                message: 'Early Adopter #${user['earlyAdopterNumber']}',
                                                child: const Icon(Icons.star, size: 14, color: Colors.amber),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _buildStatusBadge(user['status'] as String? ?? '-'),
                                    ),
                                DataCell((user['suspended'] as bool?) == true
                                    ? const Icon(Icons.block, size: 16, color: Colors.red)
                                    : const Icon(Icons.check_circle, size: 16, color: Colors.green)),
                                    DataCell(
                                      PopupMenuButton<String>(
                                        onSelected: (value) => _handleAction(value, user),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'manage',
                                            child: Row(
                                              children: [
                                                Icon(Icons.settings, size: 16),
                                                SizedBox(width: 8),
                                                Text('Urus Subscription'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'reset_password',
                                            child: Row(
                                              children: [
                                                Icon(Icons.key, size: 16),
                                                SizedBox(width: 8),
                                                Text('Reset Password'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'change_plan',
                                            child: Row(
                                              children: [
                                                Icon(Icons.swap_horiz, size: 16),
                                                SizedBox(width: 8),
                                                Text('Tukar Plan'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'add_payment',
                                            child: Row(
                                              children: [
                                                Icon(Icons.payment, size: 16),
                                                SizedBox(width: 8),
                                                Text('Tambah Bayaran'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'suspend',
                                            child: Row(
                                              children: [
                                                Icon(Icons.block, size: 16),
                                                SizedBox(width: 8),
                                                Text('Suspend'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, size: 16, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Hapus Pengguna', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                        child: const Icon(Icons.more_vert),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        
        // Dialogs
        if (_showManageDialog) _buildManageDialog(),
        if (_showResetPasswordDialog) _buildResetPasswordDialog(),
        if (_showDeleteDialog) _buildDeleteDialog(),
        if (_showSuspendDialog) _buildSuspendDialog(),
        if (_showChangePlanDialog) _buildChangePlanDialog(),
        if (_showAddPaymentDialog) _buildAddPaymentDialog(),
      ],
    );
  }

  Widget _buildManageDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Subscription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Activate or cancel subscription for ${_selectedUser?['name'] ?? 'user'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text('Duration Package', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _durationMonths,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '1', child: Text('1 Bulan - RM39')),
                DropdownMenuItem(value: '3', child: Text('3 Bulan - RM117')),
                DropdownMenuItem(value: '6', child: Text('6 Bulan - RM215 (Save 8%)')),
                DropdownMenuItem(value: '12', child: Text('12 Bulan - RM398 (Save 15%)')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _durationMonths = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showManageDialog = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement activation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Activation - to be implemented')),
                    );
                    setState(() => _showManageDialog = false);
                  },
                  child: const Text('Activate Subscription'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetPasswordDialog() {
    return AlertDialog(
      title: Text(_tempPassword.isEmpty ? 'Reset Password Pengguna' : 'Password Telah Direset'),
      content: _tempPassword.isEmpty
          ? Text('Adakah anda pasti mahu mereset password untuk ${_selectedUser?['email']}?')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Password sementara untuk ${_selectedUser?['email']}:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tempPassword,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(_copiedPassword ? Icons.check : Icons.copy),
                        color: _copiedPassword ? Colors.green : null,
                        onPressed: () async {
                          // TODO: Copy to clipboard
                          setState(() => _copiedPassword = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copiedPassword = false);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow[200]!),
                  ),
                  child: Text(
                    '⚠️ Penting: Kongsi password ini dengan pengguna secara selamat. Password ini tidak akan dipaparkan lagi selepas ditutup.',
                    style: TextStyle(fontSize: 12, color: Colors.yellow[900]),
                  ),
                ),
              ],
            ),
      actions: [
        if (_tempPassword.isEmpty)
          TextButton(
            onPressed: () => setState(() => _showResetPasswordDialog = false),
            child: const Text('Batal'),
          ),
        if (_tempPassword.isEmpty)
          ElevatedButton(
            onPressed: () => _handleResetPassword(),
            child: const Text('Reset Password'),
          )
        else
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showResetPasswordDialog = false;
                _tempPassword = '';
                _copiedPassword = false;
              });
            },
            child: const Text('Tutup'),
          ),
      ],
    );
  }

  Widget _buildDeleteDialog() {
    return AlertDialog(
      title: const Text('Hapus Pengguna'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adakah anda pasti mahu menghapus pengguna ${_selectedUser?['email']}?'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Text(
              '⚠️ Amaran: Tindakan ini tidak boleh dibatalkan!\n\nSemua data pengguna termasuk produk, stok, pesanan, dan rekod lain akan dihapus sepenuhnya.',
              style: TextStyle(fontSize: 12, color: Colors.red[900], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showDeleteDialog = false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
            onPressed: () => _handleDeleteUser(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Hapus Pengguna'),
        ),
      ],
    );
  }

  Widget _buildSuspendDialog() {
    final isSuspended = _selectedUser?['suspended'] as bool? ?? false;
    return AlertDialog(
      title: Text(isSuspended ? 'Aktifkan Pengguna' : 'Suspend Pengguna'),
      content: Text(
        isSuspended
            ? 'Adakah anda pasti mahu mengaktifkan semula pengguna ${_selectedUser?['email']}?'
            : 'Adakah anda pasti mahu menyuspend pengguna ${_selectedUser?['email']}?',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _showSuspendDialog = false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
            onPressed: () => _handleSuspendUser(isSuspended),
          child: Text(isSuspended ? 'Aktifkan' : 'Suspend'),
        ),
      ],
    );
  }

  Widget _buildChangePlanDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activate/Change Subscription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Change subscription for ${_selectedUser?['email']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text('Duration Package', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPlan.isEmpty ? '1' : _selectedPlan,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: '1', child: Text('1 Bulan - RM39')),
                DropdownMenuItem(value: '3', child: Text('3 Bulan - RM117')),
                DropdownMenuItem(value: '6', child: Text('6 Bulan - RM215 (Save 8%)')),
                DropdownMenuItem(value: '12', child: Text('12 Bulan - RM398 (Save 15%)')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedPlan = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showChangePlanDialog = false),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedPlan.isEmpty
                      ? null
                      : () {
                          // TODO: Implement plan change
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Plan change - to be implemented')),
                          );
                          setState(() => _showChangePlanDialog = false);
                          _loadUsers();
                        },
                  child: const Text('Update Subscription'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPaymentDialog() {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambah Bayaran Manual',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Rekod bayaran manual untuk ${_selectedUser?['email']}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Amaun (RM)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(() => _paymentAmount = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Kaedah Bayaran',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual/Cash')),
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'fpx', child: Text('FPX')),
                DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                DropdownMenuItem(value: 'other', child: Text('Lain-lain')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nota (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => setState(() => _paymentNotes = value),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[200]!),
              ),
              child: Text(
                '⚠️ Bayaran manual tidak akan mengaktifkan subscription secara automatik. Gunakan "Tukar Plan" untuk mengaktifkan subscription pengguna.',
                style: TextStyle(fontSize: 12, color: Colors.yellow[900]),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showAddPaymentDialog = false),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _paymentAmount.isEmpty || 
                      double.tryParse(_paymentAmount) == null ||
                      _isProcessing
                      ? null
                      : () => _handleAddPayment(),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tambah Bayaran'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddPayment() async {
    if (_selectedUser == null) return;

    setState(() => _isProcessing = true);
    try {
      final amount = double.parse(_paymentAmount);
      await _subscriptionService.addManualPayment(
        userId: _selectedUser!['id'] as String,
        amount: amount,
        paymentMethod: _paymentMethod,
        notes: _paymentNotes.isEmpty ? null : _paymentNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showAddPaymentDialog = false;
          _selectedUser = null;
          _paymentAmount = '';
          _paymentMethod = 'manual';
          _paymentNotes = '';
        });
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to add payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    if (_selectedUser == null) return;

    setState(() => _isProcessing = true);
    try {
      final response = await supabase.functions.invoke('admin-users', body: {
        'action': 'reset_password',
        'userId': _selectedUser!['id'],
      });

      if (response.data != null && response.data['tempPassword'] != null) {
        setState(() {
          _tempPassword = response.data['tempPassword'] as String;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Password reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to reset password');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reset password: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _showResetPasswordDialog = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleDeleteUser() async {
    if (_selectedUser == null) return;

    setState(() => _isProcessing = true);
    try {
      final response = await supabase.functions.invoke('admin-users', body: {
        'action': 'delete',
        'userId': _selectedUser!['id'],
      });

      if (response.data != null && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _showDeleteDialog = false;
            _selectedUser = null;
          });
          _loadUsers();
        }
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to delete user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleSuspendUser(bool isSuspended) async {
    if (_selectedUser == null) return;

    setState(() => _isProcessing = true);
    try {
      final response = await supabase.functions.invoke('admin-users', body: {
        'action': isSuspended ? 'activate' : 'suspend',
        'userId': _selectedUser!['id'],
      });

      if (response.data != null && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ User ${isSuspended ? 'activated' : 'suspended'} successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _showSuspendDialog = false;
            _selectedUser = null;
          });
          _loadUsers();
        }
      } else {
        throw Exception('Failed to ${isSuspended ? 'activate' : 'suspend'} user');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to ${isSuspended ? 'activate' : 'suspend'} user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

