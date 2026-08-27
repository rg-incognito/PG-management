import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../models/payment_claim.dart';
import '../../models/staff.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class ActivityLogScreen extends ConsumerWidget {
  final String pgId;
  const ActivityLogScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(recentPaymentsProvider(pgId));
    final claimsAsync = ref.watch(recentResolvedClaimsProvider(pgId));
    final activeTenantsAsync = ref.watch(tenantsProvider(pgId));
    final exitedTenantsAsync = ref.watch(exitedTenantsProvider(pgId));
    final currentStaffAsync = ref.watch(currentStaffProvider);
    final currentUid = ref.watch(authServiceProvider).currentUser?.uid;
    final isOwner = currentStaffAsync.value?.role == StaffRole.owner;
    final allStaffAsync = isOwner ? ref.watch(allStaffProvider) : const AsyncValue<List<Staff>>.data([]);

    final ready = paymentsAsync.hasValue &&
        claimsAsync.hasValue &&
        activeTenantsAsync.hasValue &&
        exitedTenantsAsync.hasValue &&
        (!isOwner || allStaffAsync.hasValue);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(
              context,
              payments: paymentsAsync.value!,
              claims: claimsAsync.value!,
              tenants: [...activeTenantsAsync.value!, ...exitedTenantsAsync.value!],
              staff: allStaffAsync.value ?? const [],
              currentUid: currentUid,
            ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Payment> payments,
    required List<PaymentClaim> claims,
    required List<Tenant> tenants,
    required List<Staff> staff,
    required String? currentUid,
  }) {
    final tenantNames = {for (final t in tenants) t.id: t.name};
    final staffNames = {for (final s in staff) s.id: s.name};

    String actorLabel(String? uid) {
      if (uid == null) return 'Unknown';
      if (uid == currentUid) return 'You';
      return staffNames[uid] ?? 'Staff member';
    }

    final entries = <_ActivityEntry>[
      for (final p in payments)
        _ActivityEntry(
          time: p.markedAt,
          icon: Icons.check_circle,
          color: Colors.green,
          text:
              'Marked ₹${p.amountPaid.toStringAsFixed(0)} paid for ${tenantNames[p.tenantId] ?? 'a tenant'} · ${p.month}',
          actor: actorLabel(p.markedBy),
        ),
      for (final c in claims)
        _ActivityEntry(
          time: c.reviewedAt,
          icon: c.status == PaymentClaimStatus.approved ? Icons.thumb_up : Icons.thumb_down,
          color: c.status == PaymentClaimStatus.approved ? Colors.green : Colors.red,
          text:
              '${c.status == PaymentClaimStatus.approved ? 'Approved' : 'Rejected'} claim from ${tenantNames[c.tenantId] ?? 'a tenant'} · ${c.month}',
          actor: actorLabel(c.reviewedBy),
        ),
    ]..sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));

    if (entries.isEmpty) {
      return const Center(child: Text('No activity yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: Icon(e.icon, color: e.color),
          title: Text(e.text),
          subtitle: Text('${e.actor}${e.time != null ? ' · ${DateFormat.yMMMd().add_jm().format(e.time!)}' : ''}'),
        );
      },
    );
  }
}

class _ActivityEntry {
  final DateTime? time;
  final IconData icon;
  final Color color;
  final String text;
  final String actor;
  _ActivityEntry({required this.time, required this.icon, required this.color, required this.text, required this.actor});
}
