import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/tenant.dart';
import '../../services/providers.dart';

class UploadReceiptSheet extends ConsumerStatefulWidget {
  final Tenant tenant;
  final String month;
  const UploadReceiptSheet({super.key, required this.tenant, required this.month});

  @override
  ConsumerState<UploadReceiptSheet> createState() => _UploadReceiptSheetState();
}

class _UploadReceiptSheetState extends ConsumerState<UploadReceiptSheet> {
  File? _picked;
  bool _submitting = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _picked = File(picked.path));
  }

  Future<void> _submit() async {
    if (_picked == null) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final url = await ref.read(storageServiceProvider).uploadReceipt(
            widget.tenant.pgId,
            widget.tenant.id,
            widget.month,
            _picked!,
          );
      await ref.read(firestoreServiceProvider).submitPaymentClaim(
            tenantId: widget.tenant.id,
            tenantAuthUid: uid,
            pgId: widget.tenant.pgId,
            month: widget.month,
            receiptUrl: url,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upload payment receipt', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_picked != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_picked!, height: 200, fit: BoxFit.contain),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('No screenshot selected'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  onPressed: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  onPressed: () => _pick(ImageSource.camera),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_picked == null || _submitting) ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
