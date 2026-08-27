import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_ticket.dart';
import '../../services/providers.dart';

class MaintenanceScreen extends ConsumerWidget {
  final String pgId;
  const MaintenanceScreen({super.key, required this.pgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsProvider(pgId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          bottom: const TabBar(tabs: [Tab(text: 'Open'), Tab(text: 'In progress'), Tab(text: 'Resolved')]),
        ),
        body: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data: (tickets) => TabBarView(
            children: [
              _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.open).toList()),
              _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.inProgress).toList()),
              _TicketList(tickets: tickets.where((t) => t.status == TicketStatus.resolved).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  final List<MaintenanceTicket> tickets;
  const _TicketList({required this.tickets});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(child: Text('Nothing here.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _TicketCard(ticket: tickets[i]),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  final MaintenanceTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  bool _updating = false;

  Future<void> _setStatus(TicketStatus status) async {
    String? note;
    if (status == TicketStatus.resolved) {
      final noteController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mark resolved'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'Resolution note (optional)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Resolve')),
          ],
        ),
      );
      if (confirmed != true) return;
      note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
    }

    setState(() => _updating = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      await ref.read(firestoreServiceProvider).updateTicketStatus(
            ticketId: widget.ticket.id,
            status: status,
            resolutionNote: note,
            resolvedByUid: status == TicketStatus.resolved ? uid : null,
          );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('${t.tenantName}${t.createdAt != null ? ' · ${DateFormat.yMMMd().format(t.createdAt!)}' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(t.description),
            if (t.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => Dialog(child: Image.network(t.photoUrl!))),
                  child: Image.network(t.photoUrl!, height: 120, fit: BoxFit.cover),
                ),
              ),
            ],
            if (t.status == TicketStatus.resolved && t.resolutionNote != null) ...[
              const SizedBox(height: 8),
              Text('Resolution: ${t.resolutionNote}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (t.status != TicketStatus.resolved) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (t.status == TicketStatus.open)
                    TextButton(
                      onPressed: _updating ? null : () => _setStatus(TicketStatus.inProgress),
                      child: const Text('Start progress'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _updating ? null : () => _setStatus(TicketStatus.resolved),
                    child: _updating
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
