import 'package:flutter/material.dart';

/// Shows a confirmation dialog; returns true if the user confirmed sign out.
Future<bool> confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You\'ll need to sign in again to access your account.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign out')),
      ],
    ),
  );
  return confirmed ?? false;
}
