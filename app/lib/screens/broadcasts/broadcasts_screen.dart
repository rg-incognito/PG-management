import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/broadcast.dart';
import '../../services/providers.dart';

class BroadcastsScreen extends ConsumerStatefulWidget {
  final String pgId;
  const BroadcastsScreen({super.key, required this.pgId});

  @override
  ConsumerState<BroadcastsScreen> createState() => _BroadcastsScreenState();
}

class _BroadcastsScreenState extends ConsumerState<BroadcastsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(firestoreServiceProvider).sendBroadcast(
            pgId: widget.pgId,
            title: title,
            message: message,
            sentByUid: uid,
          );
      _titleController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement sent to all tenants.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final broadcastsAsync = ref.watch(broadcastsProvider(widget.pgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _sending
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.campaign),
                    label: const Text('Send to all tenants'),
                    onPressed: _sending ? null : _send,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: broadcastsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (broadcasts) {
                if (broadcasts.isEmpty) {
                  return const Center(child: Text('No announcements sent yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: broadcasts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _BroadcastTile(broadcast: broadcasts[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastTile extends StatelessWidget {
  final Broadcast broadcast;
  const _BroadcastTile({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(broadcast.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(broadcast.message),
      trailing: broadcast.sentAt != null ? Text(DateFormat.MMMd().add_jm().format(broadcast.sentAt!)) : null,
    );
  }
}
