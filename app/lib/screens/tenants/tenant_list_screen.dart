import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/payment.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';
import 'mark_paid_dialog.dart';

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

final _paymentsThisMonthProvider = StreamProvider.family((ref, String pgId) {
  return ref.watch(firestoreServiceProvider).watchPaymentsForPgAndMonth(pgId, _currentMonthKey());
});

class TenantListScreen extends ConsumerStatefulWidget {
  final String pgId;
  const TenantListScreen({super.key, required this.pgId});

  @override
  ConsumerState<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends ConsumerState<TenantListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(tenantsProvider(widget.pgId));
    final paymentsAsync = ref.watch(_paymentsThisMonthProvider(widget.pgId));
    final paymentsByTenant = <String, Payment>{
      for (final p in paymentsAsync.value ?? const <Payment>[]) p.tenantId: p,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tenants/new', extra: widget.pgId),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search tenants',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: tenantsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
              data: (tenants) {
                final filtered = _query.isEmpty
                    ? tenants
                    : tenants
                        .where((t) =>
                            t.name.toLowerCase().contains(_query) || t.mobile.contains(_query))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No tenants found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _TenantTile(
                    tenant: filtered[i],
                    pgId: widget.pgId,
                    payment: paymentsByTenant[filtered[i].id],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  final Tenant tenant;
  final String pgId;
  final Payment? payment;
  const _TenantTile({required this.tenant, required this.pgId, this.payment});

  @override
  Widget build(BuildContext context) {
    final isPaid = payment?.status == PaymentStatus.paid;

    return ListTile(
      leading: CircleAvatar(child: Text(tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?')),
      title: Text(tenant.name),
      subtitle: Text('${tenant.mobile} · ₹${tenant.rentAmount.toStringAsFixed(0)}/mo'),
      trailing: isPaid
          ? const Chip(
              avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
              label: Text('Paid'),
              visualDensity: VisualDensity.compact,
            )
          : TextButton(
              child: const Text('Mark paid'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => MarkPaidDialog(tenant: tenant, pgId: pgId),
              ),
            ),
      onTap: () => context.push('/tenants/${tenant.id}/edit', extra: pgId),
    );
  }
}
