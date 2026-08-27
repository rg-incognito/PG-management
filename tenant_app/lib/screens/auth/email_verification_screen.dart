import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';
import '../../widgets/confirm_sign_out.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final VoidCallback onVerified;
  const EmailVerificationScreen({super.key, required this.email, required this.onVerified});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _sending = false;
  bool _checking = false;
  bool _sent = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      final verified = await ref.read(authServiceProvider).reloadAndCheckVerified();
      if (verified) {
        widget.onVerified();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not verified yet — check your inbox and tap the link.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (await confirmSignOut(context)) {
                await ref.read(authServiceProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_unread, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              Text(
                'We need to verify ${widget.email} before you can upload documents.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_sent ? 'Resend verification email' : 'Send verification email'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _checking ? null : _checkVerified,
                child: _checking
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("I've verified — continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
