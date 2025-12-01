import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';

/// Test page untuk verify image upload functionality
class TestImageUploadPage extends StatefulWidget {
  const TestImageUploadPage({super.key});

  @override
  State<TestImageUploadPage> createState() => _TestImageUploadPageState();
}

class _TestImageUploadPageState extends State<TestImageUploadPage> {
  final _imageService = ImageUploadService();
  XFile? _selectedImage;
  String? _uploadedUrl;
  bool _uploading = false;
  String? _error;
  String? _testProductId;

  @override
  void initState() {
    super.initState();
    // Generate test product ID
    _testProductId = 'test-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    setState(() {
      _selectedImage = null;
      _uploadedUrl = null;
      _error = null;
      _uploading = true;
    });

    try {
      // Pick image
      final XFile? image = source == ImageSource.gallery
          ? await _imageService.pickImageFromGallery()
          : await _imageService.pickImageFromCamera();

      if (image == null) {
        setState(() {
          _uploading = false;
          _error = 'Tiada gambar dipilih';
        });
        return;
      }

      setState(() => _selectedImage = image);

      // Upload image
      final url = await _imageService.uploadProductImage(
        image,
        _testProductId!,
      );

      setState(() {
        _uploadedUrl = url;
        _uploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gambar berjaya dimuat naik!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _uploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ralat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _testDelete() async {
    if (_uploadedUrl == null) return;

    setState(() => _uploading = true);

    try {
      await _imageService.deleteProductImage(_uploadedUrl!);
      
      setState(() {
        _uploadedUrl = null;
        _uploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gambar berjaya dipadam!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _uploading = false;
      });
    }
  }

  Future<void> _checkBucketAccess() async {
    setState(() {
      _error = null;
      _uploading = true;
    });

    try {
      // Try to list files in bucket to verify access
      final files = await supabase.storage
          .from('product-images')
          .list();

      setState(() => _uploading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bucket access OK! Found ${files.length} files'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Bucket access error: $e';
        _uploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Bucket access failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test Image Upload'),
            Text(
              'Verify Supabase Storage',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Bucket Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Bucket Name', 'product-images'),
                    _buildInfoRow('Test Product ID', _testProductId ?? 'N/A'),
                    _buildInfoRow('Status', 'Public'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Bucket Access
            ElevatedButton.icon(
              onPressed: _uploading ? null : _checkBucketAccess,
              icon: const Icon(Icons.check_circle),
              label: const Text('Test Bucket Access'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Upload Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _pickAndUploadImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Upload dari Galeri'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _pickAndUploadImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Ambil Gambar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loading Indicator
            if (_uploading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Memuat naik gambar...'),
                    ],
                  ),
                ),
              ),

            // Error Display
            if (_error != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Ralat',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
              ),

            // Selected Image Preview
            if (_selectedImage != null)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Gambar Dipilih',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FutureBuilder<List<int>>(
                        future: _selectedImage!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                Uint8List.fromList(snapshot.data!),
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Path: ${_selectedImage!.path}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Uploaded URL Display
            if (_uploadedUrl != null)
              Card(
                elevation: 0,
                color: Colors.green[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Upload Berjaya!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Public URL:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _uploadedUrl!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Preview uploaded image
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _uploadedUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.red),
                                    SizedBox(height: 8),
                                    Text('Gagal memuat gambar'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _uploading ? null : _testDelete,
                        icon: const Icon(Icons.delete),
                        label: const Text('Padam Gambar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

