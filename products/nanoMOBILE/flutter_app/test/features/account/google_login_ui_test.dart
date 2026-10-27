import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/features/account/application/account_providers.dart';
import 'package:nanoai/features/account/application/auth_controller.dart';
import 'package:nanoai/features/account/domain/auth_repository.dart';
import 'package:nanoai/features/account/domain/account_exceptions.dart';
import 'package:nanoai/features/account/presentation/screens/login_screen.dart';

class _Repository extends Fake implements AuthRepository {}

class _Controller extends AuthController {
  _Controller() : super(_Repository());
  Completer<String?> result = Completer<String?>();
  int calls = 0;
  @override
  Future<String?> continueWithGoogle() {
    calls++;
    return result.future;
  }
}

void main() {
  testWidgets(
    'Google se abre en una pulsación; cancelar permite reintento sin entrar',
    (tester) async {
      final controller = _Controller();
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Sesión iniciada')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final google = find.text('Continuar con Google');
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pump();
      expect(controller.calls, 1);
      controller.result.completeError(const GoogleSignInCancelledException());
      await tester.pumpAndSettle();
      expect(find.text('Sesión iniciada'), findsNothing);
      controller.result = Completer<String?>();
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pump();
      expect(controller.calls, 2);
      controller.result.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Sesión iniciada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
