import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/bed.dart';
import '../../models/payment.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String pgId;
  const ReportsScreen({super.key, required this.pgId});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(tenantsProvider(widget.pgId));
    final bedsAsync = ref.watch(bedsProvider(widget.pgId));
    final paymentsAsync = ref.watch(paymentsForMonthProvider((pgId: widget.pgId, month: _monthKey)));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
              Text(DateFormat.yMMMM().format(_month), style: Theme.of(context).textTheme.titleMedium),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftMonth(1)),
            ],
          ),
          const SizedBox(height: 16),
          if (!tenantsAsync.hasValue || !bedsAsync.hasValue || !paymentsAsync.hasValue)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else
            _ReportBody(
              tenants: tenantsAsync.value!,
              beds: bedsAsync.value!,
              payments: paymentsAsync.value!,
            ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final List<Tenant> tenants;
  final List<Bed> beds;
  final List<Payment> payments;
  const _ReportBody({required this.tenants, required this.beds, required this.payments});

  @override
  Widget build(BuildContext context) {
    final paidPayments = payments.where((p) => p.status == PaymentStatus.paid).toList();
    final collected = paidPayments.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final expected = tenants.fold<double>(0, (sum, t) => sum + t.rentAmount);
    final paidTenantIds = paidPayments.map((p) => p.tenantId).toSet();
    final pendingTenants = tenants.where((t) => !paidTenantIds.contains(t.id)).toList();
    final pendingAmount = pendingTenants.fold<double>(0, (sum, t) => sum + t.rentAmount);
    final collectionPct = expected == 0 ? 0.0 : (collected / expected * 100).clamp(0, 100);

    final occupiedBeds = beds.where((b) => b.isOccupied).length;
    final totalBeds = beds.length;
    final occupancyPct = totalBeds == 0 ? 0.0 : (occupiedBeds / totalBeds * 100).clamp(0, 100);

    final byMode = <PaymentMode, double>{};
    for (final p in paidPayments) {
      byMode[p.mode] = (byMode[p.mode] ?? 0) + p.amountPaid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReportCard(
          title: 'Rent collection',
          color: Colors.green,
          rows: [
            'Collected: ₹${collected.toStringAsFixed(0)} of ₹${expected.toStringAsFixed(0)} (${collectionPct.toStringAsFixed(0)}%)',
            'Paid tenants: ${paidPayments.length} of ${tenants.length}',
          ],
        ),
        const SizedBox(height: 12),
        _ReportCard(
          title: 'Pending dues',
          color: Colors.orange,
          rows: [
            'Pending amount: ₹${pendingAmount.toStringAsFixed(0)}',
            'Pending tenants: ${pendingTenants.length}',
            if (pendingTenants.isNotEmpty)
              'Names: ${pendingTenants.map((t) => t.name).join(', ')}',
          ],
        ),
        const SizedBox(height: 12),
        _ReportCard(
          title: 'Occupancy',
          color: Colors.blueGrey,
          rows: [
            'Occupied beds: $occupiedBeds of $totalBeds (${occupancyPct.toStringAsFixed(0)}%)',
            'Empty beds: ${totalBeds - occupiedBeds}',
          ],
        ),
        if (byMode.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Collected by mode',
            color: Colors.indigo,
            rows: [
              for (final entry in byMode.entries)
                '${entry.key.name.toUpperCase()}: ₹${entry.value.toStringAsFixed(0)}',
            ],
          ),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> rows;
  const _ReportCard({required this.title, required this.color, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            const SizedBox(height: 8),
            for (final row in rows) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(row)),
          ],
        ),
      ),
    );
  }
}
