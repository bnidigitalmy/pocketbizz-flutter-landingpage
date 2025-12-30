import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/image_upload_service.dart';

class ProductImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final Function(String? imageUrl) onImageChanged;
  
  const ProductImagePicker({
    super.key,
    this.initialImageUrl,
    required this.onImageChanged,
  });

  @override
  State<ProductImagePicker> createState() => _ProductImagePickerState();
}

class _ProductImagePickerState extends State<ProductImagePicker> {
  final ImageUploadService _imageService = ImageUploadService();
  String? _currentImageUrl;
  XFile? _pendingImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _loading = true);

    try {
      final XFile? image = source == ImageSource.gallery
          ? await _imageService.pickImageFromGallery()
          : await _imageService.pickImageFromCamera();

      if (image != null) {
        setState(() {
          _pendingImage = image;
          _currentImageUrl = null; // Clear old URL
        });
        
        // Notify parent that image has changed (will upload when saving product)
        widget.onImageChanged(null); // Null means "pending upload"
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar gagal dipilih. Sila cuba lagi.'),
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Gambar'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_currentImageUrl != null || _pendingImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Padam Gambar'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentImageUrl = null;
                    _pendingImage = null;
                  });
                  widget.onImageChanged(null);
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_loading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pendingImage != null) {
      return FutureBuilder<Uint8List>(
        future: _pendingImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: MemoryImage(snapshot.data!),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(_currentImageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Placeholder
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!, width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Tiada Gambar',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gambar Produk',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: _buildImagePreview(),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
              _currentImageUrl != null || _pendingImage != null
                  ? 'Tukar Gambar'
                  : 'Tambah Gambar',
            ),
          ),
        ),
      ],
    );
  }

  // Expose pending image for parent to upload
  XFile? get pendingImage => _pendingImage;
}

