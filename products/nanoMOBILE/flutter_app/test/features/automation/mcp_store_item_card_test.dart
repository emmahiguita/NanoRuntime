import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_store_catalog.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'package:nanoai/features/automation/presentation/widgets/mcp/mcp_store_components.dart';

void main() {
  testWidgets('McpStoreItemCard renders without RenderFlex overflow on narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final visual = AutomationVisual.of(context);
              return SizedBox(
                width: 320,
                child: McpStoreItemCard(
                  item: const McpStoreItem(
                    id: 'test-remote',
                    name: 'Servidor MCP remoto propio',
                    author: 'Endpoint configurable',
                    category: McpStoreCategory.developer,
                    description:
                        'Conecta un servidor real compatible con Streamable HTTP. '
                        'Nano no aloja ese servidor ni lo usa como modelo conversacional.',
                    repositoryUrl: '',
                    defaultEndpoint: '',
                    transport: McpTransportKind.streamableHttp,
                    tags: [],
                  ),
                  visual: visual,
                  isConnected: false,
                  onConnect: () {},
                  onDisconnect: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PLANTILLA LISTA PARA CONFIGURAR'), findsOneWidget);
    expect(find.text('Configurar'), findsOneWidget);
  });
}
