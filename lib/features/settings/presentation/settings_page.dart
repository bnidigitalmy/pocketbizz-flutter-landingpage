/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/services/user_preferences_service.dart';
import '../../../core/utils/pwa_update_notifier.dart';
import '../../onboarding/services/onboarding_service.dart';

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
  final _imageUploadService = ImageUploadService();
  final _imagePicker = ImagePicker();
  final _preferencesService = UserPreferencesService();
  bool _uploadingQrCode = false;
  
  // App Preferences
  int _claimGracePeriodDays = 7;

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
  
  // Prefix Controllers
  final _invoicePrefixController = TextEditingController();
  final _claimPrefixController = TextEditingController();
  final _paymentPrefixController = TextEditingController();
  final _poPrefixController = TextEditingController();
  final _bookingPrefixController = TextEditingController();

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
  bool _checkingForUpdate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBusinessProfile();
    _loadUserProfile();
    _loadAppPreferences();
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
    _invoicePrefixController.dispose();
    _claimPrefixController.dispose();
    _paymentPrefixController.dispose();
    _poPrefixController.dispose();
    _bookingPrefixController.dispose();
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
        _invoicePrefixController.text = profile.invoicePrefix ?? '';
        _claimPrefixController.text = profile.claimPrefix ?? '';
        _paymentPrefixController.text = profile.paymentPrefix ?? '';
        _poPrefixController.text = profile.poPrefix ?? '';
        _bookingPrefixController.text = profile.bookingPrefix ?? '';
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

  Future<void> _loadAppPreferences() async {
    try {
      final gracePeriod = await _preferencesService.getClaimGracePeriodDays();
      if (mounted) {
        setState(() {
          _claimGracePeriodDays = gracePeriod;
        });
      }
    } catch (e) {
      debugPrint('Error loading app preferences: $e');
    }
  }

  Future<void> _saveAppPreferences() async {
    try {
      await _preferencesService.setClaimGracePeriodDays(_claimGracePeriodDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tetapan aplikasi berjaya disimpan!'),
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
        invoicePrefix: _invoicePrefixController.text.trim().isEmpty
            ? null
            : _invoicePrefixController.text.trim().toUpperCase(),
        claimPrefix: _claimPrefixController.text.trim().isEmpty
            ? null
            : _claimPrefixController.text.trim().toUpperCase(),
        paymentPrefix: _paymentPrefixController.text.trim().isEmpty
            ? null
            : _paymentPrefixController.text.trim().toUpperCase(),
        poPrefix: _poPrefixController.text.trim().isEmpty
            ? null
            : _poPrefixController.text.trim().toUpperCase(),
        bookingPrefix: _bookingPrefixController.text.trim().isEmpty
            ? null
            : _bookingPrefixController.text.trim().toUpperCase(),
      );

      // Update onboarding progress
      OnboardingService().markProfileCompleted();

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

  Future<void> _uploadQrCode() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Sumber Gambar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image == null) return;

      setState(() => _uploadingQrCode = true);

      // Get current user ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Supabase Storage
      final imageUrl = await _imageUploadService.uploadQrCodeImage(image, userId);

      // Update controller with the URL
      _paymentQrCodeController.text = imageUrl;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR Code berjaya diupload!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat upload QR Code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingQrCode = false);
      }
    }
  }

  void _removeQrCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang QR Code?'),
        content: const Text('Adakah anda pasti mahu membuang QR Code ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              _paymentQrCodeController.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Buang', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

            const SizedBox(height: 32),

            _buildSectionHeader(
              'Prefix Nombor Dokumen',
              Icons.confirmation_number_rounded,
              'Prefix untuk nombor invois, tuntutan dan pembayaran. Auto-generate dari nama perniagaan jika kosong.',
            ),
            const SizedBox(height: 16),
            _buildPrefixForm(),

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

          const SizedBox(height: 32),

          _buildSectionHeader(
            'Tetapan Aplikasi',
            Icons.settings_applications_rounded,
            'Konfigurasi tetapan aplikasi',
          ),
          const SizedBox(height: 16),
          _buildAppPreferencesForm(),

          // PWA Update Section (web only)
          if (kIsWeb) ...[
            const SizedBox(height: 32),
            _buildSectionHeader(
              'Kemaskini Aplikasi',
              Icons.system_update_rounded,
              'Semak dan kemaskini ke versi terkini',
            ),
            const SizedBox(height: 16),
            _buildUpdateSection(),
          ],

          const SizedBox(height: 32),

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
          // QR Code Upload Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadingQrCode ? null : _uploadQrCode,
                      icon: _uploadingQrCode
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_uploadingQrCode ? 'Mengupload...' : 'Upload QR Code'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_paymentQrCodeController.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _removeQrCode,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: 'Buang QR Code',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // QR Code Preview
              if (_paymentQrCodeController.text.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _paymentQrCodeController.text,
                          height: 150,
                          width: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              width: 150,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 48),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'QR Code berjaya diupload',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Manual URL Input (Alternative)
              TextFormField(
                controller: _paymentQrCodeController,
                decoration: InputDecoration(
                  labelText: 'QR Code Bayaran (Pilihan)',
                  hintText: 'Atau masukkan URL QR Code secara manual',
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
                'Upload QR Code DuitNow / Bank untuk POS. Atau masukkan URL QR Code secara manual.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrefixForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prefix akan ditambah di depan nombor dokumen. Contoh: ABC-DEL-2512-0001 (prefix ABC + DEL). Jika kosong, format tetap: DEL-2512-0001. Sistem akan auto-generate dari nama perniagaan jika kosong.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Use LayoutBuilder to adjust layout for mobile vs desktop
          LayoutBuilder(
            builder: (context, constraints) {
              // Stack vertically on mobile (< 600px width), horizontally on desktop
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    _buildPrefixField(
                      controller: _invoicePrefixController,
                      label: 'Prefix Invois',
                      hint: 'ABC (akan jadi ABC-DEL-...)',
                      icon: Icons.receipt_long,
                      suffixText: '-DEL-YYMM-0001',
                      helperText: 'Format: PREFIX-DEL-YYMM-0001',
                    ),
                    const SizedBox(height: 12),
                    _buildPrefixField(
                      controller: _claimPrefixController,
                      label: 'Prefix Tuntutan',
                      hint: 'ABC (akan jadi ABC-CLM-...)',
                      icon: Icons.description,
                      suffixText: '-CLM-YYMM-0001',
                      helperText: 'Format: PREFIX-CLM-YYMM-0001',
                    ),
                    const SizedBox(height: 12),
                    _buildPrefixField(
                      controller: _paymentPrefixController,
                      label: 'Prefix Pembayaran',
                      hint: 'ABC (akan jadi ABC-PAY-...)',
                      icon: Icons.payments,
                      suffixText: '-PAY-YYMM-0001',
                      helperText: 'Format: PREFIX-PAY-YYMM-0001',
                    ),
                    const SizedBox(height: 12),
                    _buildPrefixField(
                      controller: _poPrefixController,
                      label: 'Prefix Purchase Order',
                      hint: 'ABC (akan jadi ABC-PO-...)',
                      icon: Icons.shopping_cart,
                      suffixText: '-PO-YYMM-0001',
                      helperText: 'Format: PREFIX-PO-YYMM-0001',
                    ),
                    const SizedBox(height: 12),
                    _buildPrefixField(
                      controller: _bookingPrefixController,
                      label: 'Prefix Tempahan',
                      hint: 'ABC (akan jadi ABC-BKG-...)',
                      icon: Icons.event,
                      suffixText: '-BKG-YYMM-0001',
                      helperText: 'Format: PREFIX-BKG-YYMM-0001',
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrefixField(
                            controller: _invoicePrefixController,
                            label: 'Prefix Invois',
                            hint: 'ABC (akan jadi ABC-DEL-...)',
                            icon: Icons.receipt_long,
                            suffixText: '-DEL-YYMM-0001',
                            helperText: 'Format: PREFIX-DEL-YYMM-0001',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrefixField(
                            controller: _claimPrefixController,
                            label: 'Prefix Tuntutan',
                            hint: 'ABC (akan jadi ABC-CLM-...)',
                            icon: Icons.description,
                            suffixText: '-CLM-YYMM-0001',
                            helperText: 'Format: PREFIX-CLM-YYMM-0001',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrefixField(
                            controller: _paymentPrefixController,
                            label: 'Prefix Pembayaran',
                            hint: 'ABC (akan jadi ABC-PAY-...)',
                            icon: Icons.payments,
                            suffixText: '-PAY-YYMM-0001',
                            helperText: 'Format: PREFIX-PAY-YYMM-0001',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPrefixField(
                            controller: _poPrefixController,
                            label: 'Prefix Purchase Order',
                            hint: 'ABC (akan jadi ABC-PO-...)',
                            icon: Icons.shopping_cart,
                            suffixText: '-PO-YYMM-0001',
                            helperText: 'Format: PREFIX-PO-YYMM-0001',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPrefixField(
                            controller: _bookingPrefixController,
                            label: 'Prefix Tempahan',
                            hint: 'ABC (akan jadi ABC-BKG-...)',
                            icon: Icons.event,
                            suffixText: '-BKG-YYMM-0001',
                            helperText: 'Format: PREFIX-BKG-YYMM-0001',
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()), // Spacer for alignment
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrefixField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String suffixText,
    required String helperText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: true,
      textCapitalization: TextCapitalization.characters,
      maxLength: 10,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: suffixText,
        helperText: helperText,
        counterText: '', // Hide character counter
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) {
        if (v != null && v.isNotEmpty) {
          if (v.length < 2) {
            return 'Minimum 2 aksara';
          }
          if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v.toUpperCase())) {
            return 'Hanya huruf dan nombor';
          }
        }
        return null;
      },
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

  Widget _buildAppPreferencesForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Claim Grace Period Setting
          LayoutBuilder(
            builder: (context, constraints) {
              // Stack vertically on narrow screens, horizontally on wide screens
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tempoh Grace untuk Alert Tuntutan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Alert akan muncul selepas X hari dari tarikh penghantaran',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildGracePeriodDropdown(),
                    ),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tempoh Grace untuk Alert Tuntutan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alert akan muncul selepas X hari dari tarikh penghantaran',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _buildGracePeriodDropdown(),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ini adalah tempoh masa selepas penghantaran sebelum alert untuk buat tuntutan muncul di dashboard. Pilih "Segera" untuk alert muncul terus bila ada delivery.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingForUpdate = true);
    try {
      await PWAUpdateNotifier.forceUpdate(context);
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdate = false);
      }
    }
  }

  Widget _buildUpdateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auto-Update',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplikasi akan dikemaskini secara automatik bila anda navigate ke halaman lain.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkingForUpdate ? null : _checkForUpdate,
              icon: _checkingForUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _checkingForUpdate ? 'Menyemak...' : 'Semak Kemaskini Sekarang',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kemaskini akan diapply secara automatik bila anda navigate ke halaman lain. Anda tidak perlu refresh manual.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGracePeriodDropdown() {
    return DropdownButtonFormField<int>(
      value: _claimGracePeriodDays,
      isExpanded: true, // Prevent overflow
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: [0, 3, 7, 14, 21, 30].map((days) {
        String label;
        if (days == 0) {
          label = 'Segera';
        } else {
          label = '$days hari';
        }
        return DropdownMenuItem(
          value: days,
          child: Text(label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _claimGracePeriodDays = value;
          });
          _saveAppPreferences();
        }
      },
    );
  }

}

