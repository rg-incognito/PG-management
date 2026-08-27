import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_ticket.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class MaintenanceScreen extends ConsumerWidget {
  final Tenant tenant;
  const MaintenanceScreen({super.key, required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider(tenant.authUid ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance requests')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewTicketSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(child: Text('No requests yet. Tap + to raise one.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _TicketCard(ticket: tickets[i]),
          );
        },
      ),
    );
  }

  void _showNewTicketSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _NewTicketSheet(tenant: tenant),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final MaintenanceTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (ticket.status) {
      TicketStatus.open => ('Open', Colors.orange),
      TicketStatus.inProgress => ('In progress', Colors.blue),
      TicketStatus.resolved => ('Resolved', Colors.green),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(ticket.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Chip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  backgroundColor: color.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: color),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (ticket.createdAt != null)
              Text(DateFormat.yMMMd().format(ticket.createdAt!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(ticket.description),
            if (ticket.photoUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(ticket.photoUrl!, height: 120, fit: BoxFit.cover),
              ),
            ],
            if (ticket.status == TicketStatus.resolved && ticket.resolutionNote != null) ...[
              const SizedBox(height: 8),
              Text('Resolution: ${ticket.resolutionNote}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewTicketSheet extends ConsumerStatefulWidget {
  final Tenant tenant;
  const _NewTicketSheet({required this.tenant});

  @override
  ConsumerState<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends ConsumerState<_NewTicketSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _photo;
  bool _submitting = false;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in a title and description.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadMaintenancePhoto(widget.tenant.pgId, widget.tenant.id, _photo!);
      }
      await ref.read(firestoreServiceProvider).createTicket(
            pgId: widget.tenant.pgId,
            tenantId: widget.tenant.id,
            tenantAuthUid: widget.tenant.authUid ?? '',
            tenantName: widget.tenant.name,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            photoUrl: photoUrl,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New maintenance request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Describe the issue'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera),
            label: Text(_photo == null ? 'Attach a photo (optional)' : 'Photo attached'),
            onPressed: _pickPhoto,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
