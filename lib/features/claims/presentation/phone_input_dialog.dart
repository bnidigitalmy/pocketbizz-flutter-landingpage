import 'package:flutter/material.dart';

/// Phone Input Dialog
/// Allows user to input vendor phone number for WhatsApp
class PhoneInputDialog extends StatelessWidget {
  final String phoneInput;
  final Function(String) onPhoneChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PhoneInputDialog({
    super.key,
    required this.phoneInput,
    required this.onPhoneChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.message, color: Colors.green[600], size: 20),
          const SizedBox(width: 8),
          const Text('No. Telefon Vendor'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan nombor telefon vendor untuk hantar WhatsApp',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: phoneInput,
            onChanged: onPhoneChanged,
            decoration: const InputDecoration(
              labelText: 'Nombor Telefon',
              hintText: '0123456789 atau +60123456789',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Format akan auto-adjust untuk WhatsApp Malaysia (60XXXXXXXXX)',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: phoneInput.trim().isEmpty ? null : onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.message, size: 16),
              const SizedBox(width: 4),
              const Text('Hantar WhatsApp'),
            ],
          ),
        ),
      ],
    );
  }
}

