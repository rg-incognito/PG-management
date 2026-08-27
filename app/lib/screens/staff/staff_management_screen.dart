import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pg.dart';
import '../../models/staff.dart';
import '../../services/providers.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(allStaffProvider);
    final pgsAsync = ref.watch(assignedPgsProvider);
    final pgs = pgsAsync.value ?? const <Pg>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: FloatingActionButton(
        onPressed: pgs.isEmpty
            ? () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Add a PG first.')))
            : () => _showStaffDialog(context, ref, pgs: pgs),
        child: const Icon(Icons.add),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load staff (only owners can manage staff): $e', textAlign: TextAlign.center),
          ),
        ),
        data: (staffList) {
          if (staffList.isEmpty) {
            return const Center(child: Text('No staff yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staffList.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final staff = staffList[i];
              final pgNames = pgs
                  .where((pg) => staff.assignedPgIds.contains(pg.id))
                  .map((pg) => pg.name)
                  .join(', ');
              return ListTile(
                title: Text(staff.name),
                subtitle: Text('${staff.role.name.toUpperCase()} · ${pgNames.isEmpty ? 'No PGs assigned' : pgNames}'),
                trailing: const Icon(Icons.edit),
                onTap: () => _showStaffDialog(context, ref, pgs: pgs, existing: staff),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showStaffDialog(BuildContext context, WidgetRef ref, {required List<Pg> pgs, Staff? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emailController = TextEditingController();
    StaffRole role = existing?.role ?? StaffRole.manager;
    final selectedPgIds = {...(existing?.assignedPgIds ?? const <String>[])};
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add staff' : 'Edit staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                if (existing == null) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Used to create their admin app login',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<StaffRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: StaffRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.name.toUpperCase())))
                      .toList(),
                  onChanged: (r) => setState(() => role = r ?? role),
                ),
                const SizedBox(height: 12),
                const Text('Assigned PGs', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final pg in pgs)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(pg.name),
                    value: selectedPgIds.contains(pg.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        selectedPgIds.add(pg.id);
                      } else {
                        selectedPgIds.remove(pg.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      setState(() => saving = true);
                      try {
                        if (existing == null) {
                          final email = emailController.text.trim();
                          if (email.isEmpty) return;
                          final login = await ref.read(functionsServiceProvider).provisionStaffLogin(
                                email: email,
                                name: name,
                                role: role.name,
                                assignedPgIds: selectedPgIds.toList(),
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            await _showCredentialsDialog(context, login.email, login.password);
                          }
                        } else {
                          await ref.read(firestoreServiceProvider).updateStaffAssignment(
                                existing.id,
                                role: role.name,
                                assignedPgIds: selectedPgIds.toList(),
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      } catch (e) {
                        setState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCredentialsDialog(BuildContext context, String email, String password) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Staff login created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share these with the staff member now — the password cannot be shown again.'),
            const SizedBox(height: 16),
            SelectableText('Email: $email'),
            SelectableText('Password: $password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Email: $email\nPassword: $password'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}
