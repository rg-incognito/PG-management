import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/pg_settings.dart';
import '../../services/providers.dart';

class PgSettingsScreen extends ConsumerStatefulWidget {
  final String pgId;
  const PgSettingsScreen({super.key, required this.pgId});

  @override
  ConsumerState<PgSettingsScreen> createState() => _PgSettingsScreenState();
}

class _PgSettingsScreenState extends ConsumerState<PgSettingsScreen> {
  final _dueDateController = TextEditingController();
  final _penaltyValueController = TextEditingController();
  final _reminderDaysController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  PenaltyType _penaltyType = PenaltyType.flat;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingQr = false;
  String? _qrUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(firestoreServiceProvider).getSettings(widget.pgId);
    _dueDateController.text = settings.dueDate.toString();
    _penaltyValueController.text = settings.penaltyValue.toStringAsFixed(0);
    _reminderDaysController.text = settings.reminderDaysBefore.toString();
    _ownerNameController.text = settings.ownerName ?? '';
    _contactPhoneController.text = settings.contactPhone ?? '';
    _penaltyType = settings.penaltyType;

    final pgs = await ref.read(firestoreServiceProvider).watchPgs([widget.pgId]).first;
    if (pgs.isNotEmpty) _qrUrl = pgs.first.paymentQrUrl;

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _dueDateController.dispose();
    _penaltyValueController.dispose();
    _reminderDaysController.dispose();
    _ownerNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = PgSettings(
        pgId: widget.pgId,
        dueDate: int.tryParse(_dueDateController.text) ?? 5,
        penaltyType: _penaltyType,
        penaltyValue: double.tryParse(_penaltyValueController.text) ?? 0,
        reminderDaysBefore: int.tryParse(_reminderDaysController.text) ?? 3,
        ownerName: _ownerNameController.text.trim().isEmpty ? null : _ownerNameController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
      );
      await ref.read(firestoreServiceProvider).saveSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadQr() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() => _uploadingQr = true);
    try {
      final url = await ref.read(storageServiceProvider).uploadPgQr(widget.pgId, File(picked.path));
      await ref.read(firestoreServiceProvider).updatePgQrUrl(widget.pgId, url);
      if (mounted) setState(() => _qrUrl = url);
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('PG Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Payment QR code', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Shown to tenants in their app so they can pay rent via UPI.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_qrUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(_qrUrl!, height: 220, fit: BoxFit.contain),
            )
          else
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('No QR code uploaded yet'),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploadingQr ? null : _pickAndUploadQr,
            icon: _uploadingQr
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code),
            label: Text(_qrUrl == null ? 'Upload QR code' : 'Replace QR code'),
          ),
          const Divider(height: 40),
          Text('Receipt details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Shown on generated rent receipts as the issuer.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerNameController,
            decoration: const InputDecoration(labelText: 'Owner name (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Contact phone (optional)'),
          ),
          const Divider(height: 40),
          Text('Due date & penalty', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _dueDateController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Due date (day of month)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PenaltyType>(
            initialValue: _penaltyType,
            decoration: const InputDecoration(labelText: 'Penalty type'),
            items: PenaltyType.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase())))
                .toList(),
            onChanged: (p) => setState(() => _penaltyType = p ?? _penaltyType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _penaltyValueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _penaltyType == PenaltyType.flat ? 'Penalty amount (₹)' : 'Penalty (%)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reminderDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reminder days before due date'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}
