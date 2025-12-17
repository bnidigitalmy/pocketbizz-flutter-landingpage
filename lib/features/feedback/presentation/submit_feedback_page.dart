import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/feedback_request.dart';
import '../../../data/repositories/feedback_repository_supabase.dart';

/// Page for users to submit feedback, bug reports, feature requests, and suggestions
class SubmitFeedbackPage extends StatefulWidget {
  const SubmitFeedbackPage({super.key});

  @override
  State<SubmitFeedbackPage> createState() => _SubmitFeedbackPageState();
}

class _SubmitFeedbackPageState extends State<SubmitFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FeedbackRepositorySupabase();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = 'suggestion';
  String _selectedPriority = 'normal';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _repo.createFeedback(
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih! Feedback anda telah dihantar.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghantar feedback: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hantar Feedback'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kongsi idea, laporkan masalah, atau cadangkan ciri baru untuk PocketBizz!',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Type selection
              const Text(
                'Jenis Feedback',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('suggestion', 'Cadangan', Icons.lightbulb_outline),
                  _buildTypeChip('feature', 'Ciri Baru', Icons.add_circle_outline),
                  _buildTypeChip('bug', 'Bug Report', Icons.bug_report),
                  _buildTypeChip('other', 'Lain-lain', Icons.more_horiz),
                ],
              ),
              const SizedBox(height: 24),

              // Priority selection
              const Text(
                'Keutamaan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPriorityChip('low', 'Rendah', Colors.grey),
                  _buildPriorityChip('normal', 'Biasa', Colors.blue),
                  _buildPriorityChip('high', 'Tinggi', Colors.orange),
                  _buildPriorityChip('urgent', 'Mendesak', Colors.red),
                ],
              ),
              const SizedBox(height: 24),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk',
                  hintText: 'Ringkaskan feedback anda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 255,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan tajuk';
                  }
                  if (value.trim().length < 5) {
                    return 'Tajuk mesti sekurang-kurangnya 5 aksara';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Penerangan',
                  hintText: 'Terangkan dengan lebih lanjut...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan penerangan';
                  }
                  if (value.trim().length < 10) {
                    return 'Penerangan mesti sekurang-kurangnya 10 aksara';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Hantar Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedType = value);
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPriority = value);
        }
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
    );
  }
}

