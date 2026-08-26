import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tenant.dart';
import '../../services/providers.dart';

class TenantVerificationScreen extends ConsumerWidget {
  final String pgId;
  const TenantVerificationScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVerificationsProvider(pgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant verification')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (tenants) {
          if (tenants.isEmpty) {
            return const Center(child: Text('No tenants awaiting verification.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _VerificationCard(tenant: tenants[i]),
          );
        },
      ),
    );
  }
}

class _VerificationCard extends ConsumerStatefulWidget {
  final Tenant tenant;
  const _VerificationCard({required this.tenant});

  @override
  ConsumerState<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends ConsumerState<_VerificationCard> {
  bool _resolving = false;

  Future<void> _approve() async {
    setState(() => _resolving = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .setVerificationStatus(widget.tenant.id, VerificationStatus.verified);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject documents'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (shown to tenant)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _resolving = true);
    try {
      await ref.read(firestoreServiceProvider).setVerificationStatus(
            widget.tenant.id,
            VerificationStatus.rejected,
            note: reason.isEmpty ? null : reason,
          );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(tenant.mobile),
            const SizedBox(height: 8),
            if (tenant.documents.isEmpty)
              const Text('No documents uploaded yet.', style: TextStyle(color: Colors.grey))
            else
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _resolving ? null : _reject, child: const Text('Reject')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _resolving ? null : _approve,
                  child: _resolving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
