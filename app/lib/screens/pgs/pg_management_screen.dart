import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pg.dart';
import '../../services/providers.dart';

class PgManagementScreen extends ConsumerWidget {
  const PgManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pgsAsync = ref.watch(assignedPgsProvider);
    final staffAsync = ref.watch(currentStaffProvider);
    final isOwner = staffAsync.value?.role.name == 'owner';

    return Scaffold(
      appBar: AppBar(title: const Text('PGs')),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: () => _showPgDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: pgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load PGs: $e')),
        data: (pgs) {
          if (pgs.isEmpty) {
            return const Center(child: Text('No PGs yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pgs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final pg = pgs[i];
              return ListTile(
                title: Text(pg.name),
                subtitle: Text(pg.address.isEmpty ? 'No address set' : pg.address),
                trailing: isOwner ? const Icon(Icons.edit) : null,
                onTap: isOwner ? () => _showPgDialog(context, ref, existing: pg) : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showPgDialog(BuildContext context, WidgetRef ref, {Pg? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add PG' : 'Edit PG'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();
              if (name.isEmpty) return;

              final uid = ref.read(authStateProvider).value?.uid;
              if (uid == null) return;

              if (existing == null) {
                await ref.read(firestoreServiceProvider).createPg(name: name, address: address, ownerUid: uid);
                ref.invalidate(currentStaffProvider);
              } else {
                await ref.read(firestoreServiceProvider).updatePg(existing.id, name: name, address: address);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
