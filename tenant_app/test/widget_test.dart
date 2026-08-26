// Smoke test: the login screen renders without a signed-in user.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaushik_pg_tenant/screens/auth/login_screen.dart';

void main() {
  testWidgets('Login screen shows email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Kaushik PG'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });
}
