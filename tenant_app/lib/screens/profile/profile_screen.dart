import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/tenant.dart';
import '../../services/providers.dart';

const _docTypes = ['ID Proof', 'Agreement', 'Other'];

class ProfileScreen extends ConsumerStatefulWidget {
  final Tenant tenant;
  const ProfileScreen({super.key, required this.tenant});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _uploadDocument() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Document type'),
        children: _docTypes
            .map((t) => SimpleDialogOption(onPressed: () => Navigator.of(context).pop(t), child: Text(t)))
            .toList(),
      ),
    );
    if (type == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ref.read(storageServiceProvider).uploadTenantDocument(
            widget.tenant.pgId,
            widget.tenant.id,
            File(picked.path),
          );
      await ref.read(firestoreServiceProvider).submitDocument(
            widget.tenant.id,
            TenantDocument(type: type, url: url, uploadedAt: DateTime.now()),
          );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantStreamProvider(widget.tenant.id));
    final tenant = tenantAsync.value ?? widget.tenant;

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tenant.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(tenant.mobile),
          const SizedBox(height: 16),
          _StatusBanner(tenant: tenant),
          const SizedBox(height: 24),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (tenant.documents.isEmpty)
            const Text('No documents uploaded yet.', style: TextStyle(color: Colors.grey)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tenant.documents
                .map((doc) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(child: Image.network(doc.url)),
                        ),
                        child: Column(
                          children: [
                            Image.network(doc.url, width: 100, height: 100, fit: BoxFit.cover),
                            Text(doc.type, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _uploading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: const Text('Upload document'),
            onPressed: _uploading ? null : _uploadDocument,
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Tenant tenant;
  const _StatusBanner({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tenant.verificationStatus) {
      VerificationStatus.notSubmitted => ('Not submitted — upload your documents below', Colors.grey),
      VerificationStatus.pending => ('Pending review by your PG owner', Colors.orange),
      VerificationStatus.verified => ('Verified', Colors.green),
      VerificationStatus.rejected => ('Rejected — please re-upload', Colors.red),
    };

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            if (tenant.verificationStatus == VerificationStatus.rejected && tenant.verificationNote != null) ...[
              const SizedBox(height: 4),
              Text('Reason: ${tenant.verificationNote}'),
            ],
          ],
        ),
      ),
    );
  }
}
