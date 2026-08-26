import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/payment.dart';
import '../../models/payment_claim.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class PaymentClaimsScreen extends ConsumerWidget {
  final String pgId;
  const PaymentClaimsScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(pendingClaimsProvider(pgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment claims')),
      body: claimsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load claims: $e')),
        data: (claims) {
          if (claims.isEmpty) {
            return const Center(child: Text('No pending payment claims.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: claims.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ClaimCard(claim: claims[i]),
          );
        },
      ),
    );
  }
}

class _ClaimCard extends ConsumerStatefulWidget {
  final PaymentClaim claim;
  const _ClaimCard({required this.claim});

  @override
  ConsumerState<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends ConsumerState<_ClaimCard> {
  Tenant? _tenant;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    ref.read(firestoreServiceProvider).getTenant(widget.claim.tenantId).then((t) {
      if (mounted) setState(() => _tenant = t);
    });
  }

  Future<void> _resolve(bool approve) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    double? amount = _tenant?.rentAmount;
    if (approve) {
      amount = await _promptAmount(context, _tenant?.rentAmount ?? 0);
      if (amount == null) return; // cancelled
    }

    setState(() => _resolving = true);
    try {
      await ref.read(firestoreServiceProvider).resolveClaim(
            claim: widget.claim,
            approve: approve,
            reviewerUid: uid,
            amountPaid: amount,
          );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<double?> _promptAmount(BuildContext context, double defaultAmount) {
    final controller = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm amount received'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text) ?? defaultAmount),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tenant?.name ?? 'Loading tenant…',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text('Month: ${claim.month} · Mode: ${PaymentMode.upi.name.toUpperCase()}'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(claim.receiptUrl, height: 200, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _resolving ? null : () => _resolve(false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _resolving ? null : () => _resolve(true),
                  child: _resolving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
