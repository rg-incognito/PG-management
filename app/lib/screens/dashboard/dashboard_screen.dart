import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/payment.dart';
import '../../services/providers.dart';

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pgsAsync = ref.watch(assignedPgsProvider);
    final selectedPgId = ref.watch(selectedPgIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaushik PG — Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: pgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load PGs: $e')),
        data: (pgs) {
          if (pgs.isEmpty) {
            return const Center(
              child: Text('No PGs assigned to your account yet.'),
            );
          }
          final activePgId = selectedPgId ?? pgs.first.id;
          final activePg = pgs.firstWhere((p) => p.id == activePgId, orElse: () => pgs.first);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: activePg.id,
                        decoration: const InputDecoration(labelText: 'PG'),
                        items: pgs
                            .map((pg) => DropdownMenuItem(value: pg.id, child: Text(pg.name)))
                            .toList(),
                        onChanged: (id) => ref.read(selectedPgIdProvider.notifier).state = id,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: 'PG settings',
                      onPressed: () => context.push('/settings', extra: activePg.id),
                    ),
                  ],
                ),
              ),
              Expanded(child: _DashboardStats(pgId: activePg.id)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _PendingClaimsButton(pgId: activePg.id),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.people),
                        label: const Text('View tenants'),
                        onPressed: () => context.push('/tenants', extra: activePg.id),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _PendingVerificationsButton(pgId: activePg.id),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bed),
                        label: const Text('Rooms & beds'),
                        onPressed: () => context.push('/rooms', extra: activePg.id),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: _NotifyPendingButton(pgId: activePg.id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardStats extends ConsumerWidget {
  final String pgId;
  const _DashboardStats({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider(pgId));
    final paymentsAsync = ref.watch(_paymentsThisMonthProvider(pgId));

    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load tenants: $e')),
      data: (tenants) {
        return paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load payments: $e')),
          data: (payments) {
            final paidTenantIds = payments.where((p) => p.status == PaymentStatus.paid).map((p) => p.tenantId).toSet();
            final paidCount = paidTenantIds.length;
            final pendingCount = tenants.length - paidCount;

            return GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _StatCard(label: 'Total tenants', value: '${tenants.length}', color: Colors.blueGrey),
                _StatCard(label: 'Paid this month', value: '$paidCount', color: Colors.green),
                _StatCard(label: 'Pending this month', value: '$pendingCount', color: Colors.orange),
              ],
            );
          },
        );
      },
    );
  }
}

final _paymentsThisMonthProvider = StreamProvider.family((ref, String pgId) {
  return ref.watch(firestoreServiceProvider).watchPaymentsForPgAndMonth(pgId, _currentMonthKey());
});

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PendingClaimsButton extends ConsumerWidget {
  final String pgId;
  const _PendingClaimsButton({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(pendingClaimsProvider(pgId));
    final count = claimsAsync.value?.length ?? 0;

    return OutlinedButton.icon(
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.receipt_long),
      ),
      label: const Text('Payment claims'),
      onPressed: () => context.push('/claims', extra: pgId),
    );
  }
}

class _PendingVerificationsButton extends ConsumerWidget {
  final String pgId;
  const _PendingVerificationsButton({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingVerificationsProvider(pgId));
    final count = pendingAsync.value?.length ?? 0;

    return OutlinedButton.icon(
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        child: const Icon(Icons.verified_user),
      ),
      label: const Text('Verification'),
      onPressed: () => context.push('/verification', extra: pgId),
    );
  }
}

class _NotifyPendingButton extends ConsumerStatefulWidget {
  final String pgId;
  const _NotifyPendingButton({required this.pgId});

  @override
  ConsumerState<_NotifyPendingButton> createState() => _NotifyPendingButtonState();
}

class _NotifyPendingButtonState extends ConsumerState<_NotifyPendingButton> {
  bool _sending = false;

  Future<void> _confirmAndSend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send rent reminder?'),
        content: const Text(
          "This pushes a reminder notification right now to every active tenant who hasn't paid this month yet.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final count = await ref.read(functionsServiceProvider).sendPendingReminders(widget.pgId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(count == 0 ? 'Everyone has already paid this month.' : 'Notified $count tenant(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _sending
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.notifications_active),
      label: const Text('Notify pending tenants'),
      onPressed: _sending ? null : _confirmAndSend,
    );
  }
}
