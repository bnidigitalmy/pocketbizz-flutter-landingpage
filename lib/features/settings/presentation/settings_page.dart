import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../core/supabase/supabase_client.dart';

/// Settings Page
/// Manage business profile and user profile
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final _repo = BusinessProfileRepository();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Business Profile Controllers
  final _businessNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _paymentQrCodeController = TextEditingController();

  // User Profile Controllers
  final _fullNameController = TextEditingController();
  final _userEmailController = TextEditingController();

  // Password Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _savingBusiness = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBusinessProfile();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameController.dispose();
    _taglineController.dispose();
    _registrationNumberController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _paymentQrCodeController.dispose();
    _fullNameController.dispose();
    _userEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _repo.getBusinessProfile();
      if (profile != null && mounted) {
        _businessNameController.text = profile.businessName;
        _taglineController.text = profile.tagline ?? '';
        _registrationNumberController.text = profile.registrationNumber ?? '';
        _addressController.text = profile.address ?? '';
        _phoneController.text = profile.phone ?? '';
        _emailController.text = profile.email ?? '';
        _bankNameController.text = profile.bankName ?? '';
        _accountNumberController.text = profile.accountNumber ?? '';
        _accountNameController.text = profile.accountName ?? '';
        _paymentQrCodeController.text = profile.paymentQrCode ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null && mounted) {
        _fullNameController.text = user.userMetadata?['full_name'] ?? '';
        _userEmailController.text = user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> _saveBusinessProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _savingBusiness = true);
    try {
      await _repo.saveBusinessProfile(
        businessName: _businessNameController.text.trim(),
        tagline: _taglineController.text.trim().isEmpty
            ? null
            : _taglineController.text.trim(),
        registrationNumber: _registrationNumberController.text.trim().isEmpty
            ? null
            : _registrationNumberController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim().isEmpty
            ? null
            : _accountNameController.text.trim(),
        paymentQrCode: _paymentQrCodeController.text.trim().isEmpty
            ? null
            : _paymentQrCodeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Maklumat perniagaan berjaya disimpan!'),
            backgroundColor: AppColors.success,
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
    } finally {
      if (mounted) {
        setState(() => _savingBusiness = false);
      }
    }
  }

  Future<void> _updateUserProfile() async {
    setState(() => _savingProfile = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(
          data: {'full_name': _fullNameController.text.trim()},
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil berjaya dikemaskini!'),
            backgroundColor: AppColors.success,
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
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata laluan baru tidak sepadan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata laluan mesti sekurang-kurangnya 6 aksara'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Kata laluan berjaya ditukar!'),
            backgroundColor: AppColors.success,
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
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tetapan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.business_rounded),
              text: 'Perniagaan',
            ),
            Tab(
              icon: Icon(Icons.person_rounded),
              text: 'Profil Saya',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBusinessTab(),
                _buildProfileTab(),
              ],
            ),
    );
  }

  Widget _buildBusinessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Maklumat Perniagaan',
              Icons.business_rounded,
              'Maklumat ini akan dipaparkan pada invois dan penyata tuntutan',
            ),
            const SizedBox(height: 16),
            _buildBusinessForm(),

            const SizedBox(height: 32),

            _buildSectionHeader(
              'Maklumat Akaun Bank',
              Icons.account_balance_rounded,
              'Untuk tuntutan pembayaran',
            ),
            const SizedBox(height: 16),
            _buildBankForm(),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingBusiness ? null : _saveBusinessProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: _savingBusiness
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Maklumat Profil',
            Icons.person_rounded,
            'Kemaskini maklumat peribadi anda',
          ),
          const SizedBox(height: 16),
          _buildProfileForm(),

          const SizedBox(height: 32),

          _buildSectionHeader(
            'Tukar Kata Laluan',
            Icons.lock_rounded,
            'Pastikan kata laluan sekurang-kurangnya 6 aksara',
          ),
          const SizedBox(height: 16),
          _buildPasswordForm(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBusinessForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'Nama Perniagaan *',
              hintText: 'ManisBizz',
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _taglineController,
            decoration: InputDecoration(
              labelText: 'Tagline (Pilihan)',
              hintText: 'Kuih-Muih Sedap & Berkualiti',
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _registrationNumberController,
            decoration: InputDecoration(
              labelText: 'No. Pendaftaran (Pilihan)',
              hintText: 'SSM123456789',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Alamat (Pilihan)',
              hintText: 'No. 123, Jalan Manis, Taman Sedap, 50000 Kuala Lumpur',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefon (Pilihan)',
                    hintText: '012-345 6789',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email (Pilihan)',
                    hintText: 'info@manisbizz.com',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _bankNameController,
            decoration: InputDecoration(
              labelText: 'Nama Bank (Pilihan)',
              hintText: 'Maybank / CIMB / Public Bank',
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'No. Akaun (Pilihan)',
                    hintText: '1234567890',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _accountNameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pemegang Akaun (Pilihan)',
                    hintText: 'Nama seperti di kad bank',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paymentQrCodeController,
            decoration: InputDecoration(
              labelText: 'QR Code Bayaran (Pilihan)',
              hintText: 'https://example.com/qr-code.png',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'URL gambar QR Code DuitNow / Bank untuk POS. Boleh upload ke Imgur atau Google Drive dan salin link.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Nama Penuh',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userEmailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingProfile ? null : _updateUserProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: _savingProfile
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Simpan Profil',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrentPassword,
            decoration: InputDecoration(
              labelText: 'Kata Laluan Semasa',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'Kata Laluan Baru',
              hintText: 'Minimum 6 aksara',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureNewPassword = !_obscureNewPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Sahkan Kata Laluan Baru',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _changingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: _changingPassword
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Tukar Kata Laluan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

