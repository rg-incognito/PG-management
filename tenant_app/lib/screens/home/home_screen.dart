import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';
import '../../widgets/confirm_sign_out.dart';
import '../maintenance/maintenance_screen.dart';
import '../profile/profile_screen.dart';
import 'announcements_screen.dart';
import 'upload_receipt_sheet.dart';

String currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

class HomeScreen extends ConsumerWidget {
  final Tenant tenant;
  const HomeScreen({super.key, required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider(tenant.id));
    final pgAsync = ref.watch(pgProvider(tenant.pgId));
    final month = currentMonthKey();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${tenant.name}'),
        actions: [
          _AnnouncementsButton(tenant: tenant),
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: 'Maintenance requests',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MaintenanceScreen(tenant: tenant)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(tenant: tenant)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              if (await confirmSignOut(context)) {
                await ref.read(authServiceProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load payments: $e')),
        data: (payments) {
          final currentMonthMatches = payments.where((p) => p.month == month);
          final currentPayment = currentMonthMatches.isEmpty ? null : currentMonthMatches.first;
          // Past months always show here; the current month only joins once
          // paid, so a tenant whose first-ever payment is this month still
          // sees it as a record instead of an empty list (it's also shown
          // separately, live, in the dues card above).
          final history = payments
              .where((p) => p.month != month || p.status == PaymentStatus.paid)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DuesCard(rentAmount: tenant.rentAmount, payment: currentPayment),
              const SizedBox(height: 16),
              pgAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (pg) {
                  final alreadyPaid = currentPayment?.status == PaymentStatus.paid;
                  if (pg?.paymentQrUrl == null || alreadyPaid) return const SizedBox.shrink();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Scan to pay via UPI', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(pg!.paymentQrUrl!, height: 220),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text("I've paid — upload receipt"),
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => UploadReceiptSheet(tenant: tenant, month: month),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (history.isEmpty) const Text('No past payments yet.'),
              ...history.map((p) => _HistoryTile(payment: p)),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementsButton extends ConsumerWidget {
  final Tenant tenant;
  const _AnnouncementsButton({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTenant = ref.watch(tenantStreamProvider(tenant.id)).value ?? tenant;
    final broadcasts = ref.watch(broadcastsProvider(tenant.pgId)).value ?? const [];
    final lastSeen = liveTenant.lastSeenBroadcastAt;
    final unreadCount =
        broadcasts.where((b) => lastSeen == null || (b.sentAt?.isAfter(lastSeen) ?? false)).length;

    return IconButton(
      tooltip: 'Announcements',
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        child: const Icon(Icons.campaign),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnnouncementsScreen(tenant: liveTenant)),
      ),
    );
  }
}

class _DuesCard extends StatelessWidget {
  final double rentAmount;
  final Payment? payment;
  const _DuesCard({required this.rentAmount, this.payment});

  @override
  Widget build(BuildContext context) {
    final status = payment?.status ?? PaymentStatus.pending;
    final color = switch (status) {
      PaymentStatus.paid => Colors.green,
      PaymentStatus.overdue => Colors.red,
      PaymentStatus.pending => Colors.orange,
    };
    final label = switch (status) {
      PaymentStatus.paid => 'Paid this month',
      PaymentStatus.overdue => 'Overdue',
      PaymentStatus.pending => 'Due this month',
    };

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              '₹${rentAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            if ((payment?.penaltyApplied ?? 0) > 0)
              Text('+ ₹${payment!.penaltyApplied} penalty', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Payment payment;
  const _HistoryTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMM().format(DateTime.parse('${payment.month}-01'));
    return ListTile(
      title: Text(monthLabel),
      subtitle: Text(payment.status.name.toUpperCase()),
      trailing: Text('₹${payment.amountPaid.toStringAsFixed(0)}'),
      onTap: payment.status == PaymentStatus.paid ? () => _showReceipt(context, monthLabel) : null,
    );
  }

  void _showReceipt(BuildContext context, String monthLabel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt — $monthLabel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Amount paid: ₹${payment.amountPaid.toStringAsFixed(0)}'),
            if (payment.mode != null) Text('Mode: ${payment.mode!.toUpperCase()}'),
            if (payment.markedAt != null)
              Text('Confirmed on: ${DateFormat.yMMMd().add_jm().format(payment.markedAt!)}'),
            if (payment.receiptUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(payment.receiptUrl!, height: 240, fit: BoxFit.contain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
