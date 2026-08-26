import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/messaging_service.dart';
import 'services/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await MessagingService().requestPermission();
  } catch (e) {
    if (kDebugMode) debugPrint('Messaging permission request skipped: $e');
  }
  runApp(const ProviderScope(child: KaushikPgTenantApp()));
}

class KaushikPgTenantApp extends ConsumerWidget {
  const KaushikPgTenantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Kaushik PG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  // Independent of the auth stream, since Firebase doesn't push a new
  // authStateChanges event just because the user clicked the verification
  // link elsewhere — updated explicitly via EmailVerificationScreen.
  bool? _verifiedOverride;
  User? _lastUser;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const LoginScreen();

        if (_lastUser?.uid != user.uid) {
          _lastUser = user;
          _verifiedOverride = null;
        }
        final verified = _verifiedOverride ?? user.emailVerified;
        if (!verified) {
          return EmailVerificationScreen(
            email: user.email ?? '',
            onVerified: () => setState(() => _verifiedOverride = true),
          );
        }

        final tenantAsync = ref.watch(linkedTenantProvider);
        return tenantAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (tenant) {
            if (tenant == null) return const _NoTenantRecordScreen();
            return HomeScreen(tenant: tenant);
          },
        );
      },
    );
  }
}

class _NoTenantRecordScreen extends ConsumerWidget {
  const _NoTenantRecordScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "We couldn't find a tenant record linked to this login. "
                'Ask your PG owner to check your account, then sign in again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
