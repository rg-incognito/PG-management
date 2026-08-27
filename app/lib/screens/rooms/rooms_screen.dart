import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bed.dart';
import '../../models/flat.dart';
import '../../models/room.dart';
import '../../models/room_type.dart';
import '../../services/providers.dart';

class RoomsScreen extends StatelessWidget {
  final String pgId;
  const RoomsScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rooms'),
          bottom: const TabBar(tabs: [Tab(text: 'Structure'), Tab(text: 'Flats & rooms'), Tab(text: 'Room types')]),
        ),
        body: TabBarView(
          children: [
            _StructureTab(pgId: pgId),
            _FlatsAndRoomsTab(pgId: pgId),
            _RoomTypesTab(pgId: pgId),
          ],
        ),
      ),
    );
  }
}

// ============================== Structure tab ==============================

class _StructureTab extends ConsumerWidget {
  final String pgId;
  const _StructureTab({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flatsAsync = ref.watch(flatsProvider(pgId));
    final roomsAsync = ref.watch(roomsProvider(pgId));
    final bedsAsync = ref.watch(bedsProvider(pgId));

    if (!flatsAsync.hasValue || !roomsAsync.hasValue || !bedsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final flats = flatsAsync.value!;
    final rooms = roomsAsync.value!;
    final beds = bedsAsync.value!;

    if (flats.isEmpty) {
      return const Center(child: Text('No flats set up yet. Add one in the "Flats & rooms" tab.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _LegendDot(color: Colors.green.shade400, label: 'Empty'),
            const SizedBox(width: 16),
            _LegendDot(color: Colors.blueGrey.shade400, label: 'Occupied'),
          ],
        ),
        const SizedBox(height: 16),
        for (final flat in flats) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flat.name}${flat.flatType.isNotEmpty ? ' · ${flat.flatType}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  for (final room in rooms.where((r) => r.flatId == flat.id)) ...[
                    Text('Room ${room.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final bed in beds.where((b) => b.roomId == room.id))
                          _BedChip(bed: bed, pgId: pgId),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _BedChip extends ConsumerWidget {
  final Bed bed;
  final String pgId;
  const _BedChip({required this.bed, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = bed.isOccupied ? Colors.blueGrey.shade400 : Colors.green.shade400;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showBedDetails(context, ref, bed),
      child: Container(
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(
          bed.bedLabel,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _showBedDetails(BuildContext context, WidgetRef ref, Bed bed) async {
    if (!bed.isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empty bed — assign a tenant from Add Tenant.')),
      );
      return;
    }
    final tenant = await ref.read(firestoreServiceProvider).getTenant(bed.tenantId!);
    if (!context.mounted) return;
    if (tenant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant record not found.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tenant.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Mobile: ${tenant.mobile}'),
            if (tenant.email.isNotEmpty) Text('Email: ${tenant.email}'),
            Text('Rent: ₹${tenant.rentAmount.toStringAsFixed(0)}/month'),
            Text('Deposit: ₹${tenant.depositAmount.toStringAsFixed(0)}'),
            if (tenant.joinDate != null)
              Text('Joined: ${tenant.joinDate!.day}/${tenant.joinDate!.month}/${tenant.joinDate!.year}'),
          ],
        ),
      ),
    );
  }
}

// =========================== Flats & rooms tab ==============================

class _FlatsAndRoomsTab extends ConsumerWidget {
  final String pgId;
  const _FlatsAndRoomsTab({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flatsAsync = ref.watch(flatsProvider(pgId));
    final roomsAsync = ref.watch(roomsProvider(pgId));
    final bedsAsync = ref.watch(bedsProvider(pgId));
    final typesAsync = ref.watch(roomTypesProvider(pgId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFlatDialog(context, ref, pgId: pgId),
        child: const Icon(Icons.add),
      ),
      body: flatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load flats: $e')),
        data: (flats) {
          if (flats.isEmpty) {
            return const Center(child: Text('No flats yet. Add one, e.g. "A-101" (1BHK).'));
          }
          final rooms = roomsAsync.value ?? [];
          final beds = bedsAsync.value ?? [];
          final types = typesAsync.value ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final flat in flats)
                Card(
                  child: ExpansionTile(
                    title: Text(flat.name),
                    subtitle: Text(flat.flatType),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showFlatDialog(context, ref, pgId: pgId, existing: flat);
                        } else if (action == 'delete') {
                          _confirmDeleteFlat(
                            context,
                            ref,
                            flat: flat,
                            hasRooms: rooms.any((r) => r.flatId == flat.id),
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    children: [
                      for (final room in rooms.where((r) => r.flatId == flat.id))
                        ListTile(
                          title: Text('Room ${room.roomNumber}'),
                          subtitle: Text(_typeName(types, room.roomTypeId)),
                          onTap: () => _showRenameRoomDialog(context, ref, room: room),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Rename',
                                onPressed: () => _showRenameRoomDialog(context, ref, room: room),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete room',
                                onPressed: () => _confirmDeleteRoom(
                                  context,
                                  ref,
                                  room: room,
                                  beds: beds.where((b) => b.roomId == room.id).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add room'),
                            onPressed: types.isEmpty
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Add a room type first.')),
                                    )
                                : () => _showAddRoomDialog(context, ref, pgId: pgId, flatId: flat.id, types: types),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _typeName(List<RoomType> types, String roomTypeId) {
    final matches = types.where((t) => t.id == roomTypeId);
    return matches.isEmpty ? 'Unknown type' : matches.first.name;
  }
}

Future<void> _showFlatDialog(BuildContext context, WidgetRef ref, {required String pgId, Flat? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final typeController = TextEditingController(text: existing?.flatType ?? '');

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(existing == null ? 'Add flat' : 'Edit flat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name (e.g. A-101)')),
          const SizedBox(height: 12),
          TextField(
            controller: typeController,
            decoration: const InputDecoration(labelText: 'Type (e.g. 1BHK, Studio)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final flat = Flat(
              id: existing?.id ?? '',
              pgId: pgId,
              name: nameController.text.trim(),
              flatType: typeController.text.trim(),
            );
            await ref.read(firestoreServiceProvider).upsertFlat(flat);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _confirmDeleteFlat(
  BuildContext context,
  WidgetRef ref, {
  required Flat flat,
  required bool hasRooms,
}) async {
  if (hasRooms) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete or move this flat\'s rooms first.')),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete flat?'),
      content: Text('This removes "${flat.name}" permanently.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(firestoreServiceProvider).deleteFlat(flat.id);
  }
}

Future<void> _confirmDeleteRoom(
  BuildContext context,
  WidgetRef ref, {
  required Room room,
  required List<Bed> beds,
}) async {
  if (beds.any((b) => b.isOccupied)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Move or check out occupants before deleting this room.')),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete room?'),
      content: Text('This removes room "${room.roomNumber}" and its ${beds.length} bed(s) permanently.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(firestoreServiceProvider).deleteRoom(room.id);
  }
}

Future<void> _showAddRoomDialog(
  BuildContext context,
  WidgetRef ref, {
  required String pgId,
  required String flatId,
  required List<RoomType> types,
}) {
  final roomNumberController = TextEditingController();
  RoomType selectedType = types.first;

  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomNumberController,
              decoration: const InputDecoration(labelText: 'Room number/name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RoomType>(
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: 'Room type'),
              items: types
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('${t.name} (${t.capacity} sharing, ₹${t.defaultRent.toStringAsFixed(0)})'),
                      ))
                  .toList(),
              onChanged: (t) => setState(() => selectedType = t ?? selectedType),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).createRoom(
                    pgId: pgId,
                    flatId: flatId,
                    roomNumber: roomNumberController.text.trim(),
                    roomType: selectedType,
                  );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showRenameRoomDialog(BuildContext context, WidgetRef ref, {required Room room}) {
  final controller = TextEditingController(text: room.roomNumber);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename room'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Room number/name')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(firestoreServiceProvider).renameRoom(room.id, controller.text.trim());
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

// ============================= Room types tab ================================

class _RoomTypesTab extends ConsumerWidget {
  final String pgId;
  const _RoomTypesTab({required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(roomTypesProvider(pgId));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoomTypeDialog(context, ref, pgId: pgId),
        child: const Icon(Icons.add),
      ),
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load room types: $e')),
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text('No room types yet. Add one, e.g. "3 sharing" at ₹6,000.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: types.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final type = types[i];
              return ListTile(
                title: Text(type.name),
                subtitle: Text('${type.capacity} sharing · ₹${type.defaultRent.toStringAsFixed(0)}/mo per bed'),
                trailing: const Icon(Icons.edit),
                onTap: () => _showRoomTypeDialog(context, ref, pgId: pgId, existing: type),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showRoomTypeDialog(BuildContext context, WidgetRef ref, {required String pgId, RoomType? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final rentController = TextEditingController(text: existing?.defaultRent.toStringAsFixed(0) ?? '');
  final capacityController = TextEditingController(text: existing?.capacity.toString() ?? '1');

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(existing == null ? 'Add room type' : 'Edit room type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name (e.g. "3 sharing", "Single")'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: rentController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rent per bed (₹/month)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: capacityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Beds per room of this type'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final roomType = RoomType(
              id: existing?.id ?? '',
              pgId: pgId,
              name: nameController.text.trim(),
              defaultRent: double.tryParse(rentController.text) ?? 0,
              capacity: int.tryParse(capacityController.text) ?? 1,
            );
            await ref.read(firestoreServiceProvider).upsertRoomType(roomType);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
