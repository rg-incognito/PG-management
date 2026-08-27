import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../models/bed.dart';
import '../../models/flat.dart';
import '../../models/payment.dart';
import '../../models/receipt_data.dart';
import '../../models/room.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';
import '../../services/receipt_templates.dart';

class ReceiptsScreen extends ConsumerStatefulWidget {
  final String pgId;
  const ReceiptsScreen({super.key, required this.pgId});

  @override
  ConsumerState<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends ConsumerState<ReceiptsScreen> {
  String? _selectedTenantId;
  String? _selectedPaymentId;
  ReceiptTemplate _template = ReceiptTemplate.classic;
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final activeTenants = ref.watch(tenantsProvider(widget.pgId)).value ?? const [];
    final exitedTenants = ref.watch(exitedTenantsProvider(widget.pgId)).value ?? const [];
    final tenants = [...activeTenants, ...exitedTenants];

    final beds = ref.watch(bedsProvider(widget.pgId)).value ?? const [];
    final rooms = ref.watch(roomsProvider(widget.pgId)).value ?? const [];
    final flats = ref.watch(flatsProvider(widget.pgId)).value ?? const [];

    final tenantMatches = tenants.where((t) => t.id == _selectedTenantId);
    final selectedTenant = tenantMatches.isEmpty ? null : tenantMatches.first;

    final paidPayments = selectedTenant == null
        ? const <Payment>[]
        : (ref.watch(tenantPaymentsProvider(selectedTenant.id)).value ?? const [])
            .where((p) => p.status == PaymentStatus.paid)
            .toList();
    final paymentMatches = paidPayments.where((p) => p.id == _selectedPaymentId);
    final selectedPayment = paymentMatches.isEmpty ? null : paymentMatches.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedTenantId,
            decoration: const InputDecoration(labelText: 'Tenant'),
            isExpanded: true,
            items: tenants
                .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (id) => setState(() {
              _selectedTenantId = id;
              _selectedPaymentId = null;
            }),
          ),
          const SizedBox(height: 16),
          if (selectedTenant != null) ...[
            if (paidPayments.isEmpty)
              const Text('No paid months on record for this tenant yet.', style: TextStyle(color: Colors.grey))
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentId,
                decoration: const InputDecoration(labelText: 'Paid month'),
                isExpanded: true,
                items: paidPayments
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${DateFormat.yMMMM().format(DateTime.parse('${p.month}-01'))} · Rs. ${p.amountPaid.toStringAsFixed(0)}'),
                        ))
                    .toList(),
                onChanged: (id) => setState(() => _selectedPaymentId = id),
              ),
          ],
          const SizedBox(height: 20),
          if (selectedPayment != null) ...[
            Text('Choose a template', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<ReceiptTemplate>(
              groupValue: _template,
              onChanged: (v) => setState(() => _template = v ?? _template),
              child: Column(
                children: [
                  for (final t in ReceiptTemplate.values)
                    RadioListTile<ReceiptTemplate>(
                      value: t,
                      title: Text(t.label),
                      subtitle: Text(t.description),
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: _generating
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.receipt_long),
              label: const Text('Generate receipt'),
              onPressed: _generating ? null : () => _generate(selectedTenant!, selectedPayment, beds, rooms, flats),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate(Tenant tenant, Payment payment, List<Bed> beds, List<Room> rooms, List<Flat> flats) async {
    setState(() => _generating = true);
    try {
      final pgs = await ref.read(firestoreServiceProvider).watchPgs([widget.pgId]).first;
      if (pgs.isEmpty) throw Exception('PG not found');
      final pg = pgs.first;
      final settings = await ref.read(firestoreServiceProvider).getSettings(widget.pgId);

      final data = ReceiptData(
        receiptNumber: payment.id,
        pgName: pg.name,
        pgAddress: pg.address,
        tenantName: tenant.name,
        roomLabel: _roomLabelFor(tenant, beds, rooms, flats),
        amount: payment.amountPaid,
        penaltyApplied: payment.penaltyApplied.toDouble(),
        monthLabel: DateFormat.yMMMM().format(DateTime.parse('${payment.month}-01')),
        paymentMode: payment.mode.name.toUpperCase(),
        paidDate: payment.markedAt ?? DateTime.now(),
        ownerName: settings.ownerName,
        ownerPhone: settings.contactPhone,
      );

      final bytes = await ReceiptBuilder.build(_template, data);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ReceiptPreviewScreen(bytes: bytes, fileName: 'receipt_${payment.id}.pdf')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate receipt: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _roomLabelFor(Tenant tenant, List<Bed> beds, List<Room> rooms, List<Flat> flats) {
    final bedMatches = beds.where((b) => b.id == tenant.bedId);
    if (bedMatches.isEmpty) return '—';
    final bed = bedMatches.first;

    final roomMatches = rooms.where((r) => r.id == bed.roomId);
    if (roomMatches.isEmpty) return bed.bedLabel;
    final room = roomMatches.first;

    final flatMatches = flats.where((f) => f.id == bed.flatId);
    final flatName = flatMatches.isEmpty ? '' : '${flatMatches.first.name} · ';
    return '$flatName Room ${room.roomNumber} · ${bed.bedLabel}';
  }
}

class _ReceiptPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  const _ReceiptPreviewScreen({required this.bytes, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt preview')),
      body: PdfPreview(
        build: (format) async => bytes,
        pdfFileName: fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
