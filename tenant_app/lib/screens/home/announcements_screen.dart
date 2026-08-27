import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/broadcast.dart';
import '../../models/tenant.dart';
import '../../services/providers.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  final Tenant tenant;
  const AnnouncementsScreen({super.key, required this.tenant});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark everything seen as of opening this screen — any broadcast sent
    // after this point still shows up as unread next time.
    Future.microtask(
      () => ref.read(firestoreServiceProvider).markBroadcastsSeen(widget.tenant.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final broadcastsAsync = ref.watch(broadcastsProvider(widget.tenant.pgId));
    final lastSeen = widget.tenant.lastSeenBroadcastAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: broadcastsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (broadcasts) {
          if (broadcasts.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }
          final unread = broadcasts
              .where((b) => lastSeen == null || (b.sentAt?.isAfter(lastSeen) ?? false))
              .toList();
          final read = broadcasts.where((b) => !unread.contains(b)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (unread.isNotEmpty) ...[
                Text('New', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...unread.map((b) => _AnnouncementTile(broadcast: b, unread: true)),
                const SizedBox(height: 24),
              ],
              if (read.isNotEmpty) ...[
                Text('Earlier', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...read.map((b) => _AnnouncementTile(broadcast: b, unread: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Broadcast broadcast;
  final bool unread;
  const _AnnouncementTile({required this.broadcast, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: unread ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: ListTile(
        title: Text(broadcast.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(broadcast.message),
        trailing: broadcast.sentAt != null
            ? Text(
                DateFormat.MMMd().add_jm().format(broadcast.sentAt!),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              )
            : null,
      ),
    );
  }
}
