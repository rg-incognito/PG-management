import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/broadcast.dart';
import '../../models/payment.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';
import '../profile/profile_screen.dart';
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
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load payments: $e')),
        data: (payments) {
          final currentMonthMatches = payments.where((p) => p.month == month);
          final currentPayment = currentMonthMatches.isEmpty ? null : currentMonthMatches.first;
          final history = payments.where((p) => p.month != month).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DuesCard(rentAmount: tenant.rentAmount, payment: currentPayment),
              const SizedBox(height: 16),
              _AnnouncementsSection(pgId: tenant.pgId),
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

class _AnnouncementsSection extends ConsumerWidget {
  final String pgId;
  const _AnnouncementsSection({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcastsAsync = ref.watch(broadcastsProvider(pgId));
    final broadcasts = (broadcastsAsync.value ?? const <Broadcast>[]).take(5).toList();
    if (broadcasts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.campaign, size: 20),
                SizedBox(width: 8),
                Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < broadcasts.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(broadcasts[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(broadcasts[i].message),
                    if (broadcasts[i].sentAt != null)
                      Text(
                        DateFormat.MMMd().add_jm().format(broadcasts[i].sentAt!),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (i < broadcasts.length - 1) const Divider(height: 1),
            ],
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
    );
  }
}
