import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/payment.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

class MarkPaidDialog extends ConsumerStatefulWidget {
  final Tenant tenant;
  final String pgId;
  const MarkPaidDialog({super.key, required this.tenant, required this.pgId});

  @override
  ConsumerState<MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends ConsumerState<MarkPaidDialog> {
  late final TextEditingController _amountController =
      TextEditingController(text: widget.tenant.rentAmount.toStringAsFixed(0));
  PaymentMode _mode = PaymentMode.cash;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final amount = double.tryParse(_amountController.text) ?? widget.tenant.rentAmount;

    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).markPaid(
            tenantId: widget.tenant.id,
            pgId: widget.pgId,
            month: _currentMonthKey(),
            amountPaid: amount,
            mode: _mode,
            markedByUid: uid,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark ${widget.tenant.name} as paid'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount received'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PaymentMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: PaymentMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name.toUpperCase())))
                .toList(),
            onChanged: (m) => setState(() => _mode = m ?? _mode),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
