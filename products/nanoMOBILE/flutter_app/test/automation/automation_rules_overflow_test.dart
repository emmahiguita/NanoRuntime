import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/theme/app_theme.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';
import 'package:nanoai/features/automation/presentation/screens/automation_rules_screen.dart';

void main() {
  testWidgets('RuleCard renders long outcome labels without RenderFlex 43px overflow', (
    tester,
  ) async {
    // Probar en pantalla angosta típica (360x800) donde ocurría el error original de 43px
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Regla con el outcome exacto que causaba 43px de overflow: "respuesta despachada · sin verificar"
    final rule = ScheduledRule(
      id: 'rule_whatsapp_overflow_test',
      enabled: true,
      trigger: const NotificationTrigger(
        packageName: 'com.whatsapp',
        textMatch: 'código',
      ),
      action: RuleAction.reply,
      message: 'Tu código es 1234',
      createdAt: DateTime.now().toUtc(),
      lastFiredAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      lastOutcome: 'replyDispatchedUnverified',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 330, // Ancho estrecho donde ocurría el desbordamiento
                child: RuleCard(
                  rule: rule,
                  onToggle: (_) {},
                  onDelete: () {},
                  onEdit: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verificar que no se lanzó ninguna excepción de RenderFlex
    expect(tester.takeException(), isNull);
    // Verificar que el badge de outcome se muestra con texto elíptico seguro
    expect(find.textContaining('respuesta despachada'), findsOneWidget);
    expect(find.textContaining('WhatsApp · texto "código"'), findsOneWidget);
  });
}
