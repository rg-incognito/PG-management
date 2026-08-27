import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/login_screen.dart';
import 'screens/broadcasts/broadcasts_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/rooms/rooms_screen.dart';
import 'screens/settings/pg_settings_screen.dart';
import 'screens/tenants/payment_claims_screen.dart';
import 'screens/tenants/tenant_form_screen.dart';
import 'screens/tenants/tenant_list_screen.dart';
import 'screens/tenants/tenant_verification_screen.dart';
import 'services/providers.dart';

/// Bridges a Stream (Firebase auth state) into a Listenable so GoRouter
/// re-evaluates its `redirect` callback whenever sign-in state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final loggedIn = authService.currentUser != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(
        path: '/tenants',
        builder: (_, state) => TenantListScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/tenants/new',
        builder: (_, state) => TenantFormScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/tenants/:id/edit',
        builder: (_, state) => TenantFormScreen(
          pgId: state.extra as String,
          tenantId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/claims',
        builder: (_, state) => PaymentClaimsScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, state) => PgSettingsScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/rooms',
        builder: (_, state) => RoomsScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/verification',
        builder: (_, state) => TenantVerificationScreen(pgId: state.extra as String),
      ),
      GoRoute(
        path: '/broadcasts',
        builder: (_, state) => BroadcastsScreen(pgId: state.extra as String),
      ),
    ],
  );
});
