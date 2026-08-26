import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'firebase_options.dart';
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
  runApp(const ProviderScope(child: KaushikPgAdminApp()));
}

class KaushikPgAdminApp extends ConsumerWidget {
  const KaushikPgAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Registers this device's FCM token onto the signed-in staff doc once
    // auth resolves, so payment-claim notifications reach this device.
    ref.watch(fcmTokenRegistrationProvider);
    ref.watch(claimsRefreshProvider);
    return MaterialApp.router(
      title: 'Kaushik PG Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: router,
    );
  }
}
