import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';

class ExitedTenantsScreen extends ConsumerWidget {
  final String pgId;
  const ExitedTenantsScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(exitedTenantsProvider(pgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exited tenants')),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (tenants) {
          if (tenants.isEmpty) {
            return const Center(child: Text('No exited tenants yet.'));
          }
          return ListView.separated(
            itemCount: tenants.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = tenants[i];
              final exitDate = t.exitDate;
              final exitLabel = exitDate == null
                  ? '—'
                  : '${exitDate.year}-${exitDate.month.toString().padLeft(2, '0')}-${exitDate.day.toString().padLeft(2, '0')}';
              return ListTile(
                leading: CircleAvatar(child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?')),
                title: Text(t.name),
                subtitle: Text('Exited $exitLabel${t.exitNotes != null ? ' · ${t.exitNotes}' : ''}'),
                trailing: Text('Refunded ₹${(t.depositRefunded ?? 0).toStringAsFixed(0)}'),
              );
            },
          );
        },
      ),
    );
  }
}
