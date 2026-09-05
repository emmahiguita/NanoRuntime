import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/widgets/navigation/nano_destination.dart';
import 'package:nanoai/core/widgets/navigation/nano_multi_use_nav_bar.dart';

void main() {
  testWidgets('NanoMultiUseNavBar renders correctly and handles interactions', (
    tester,
  ) async {
    NanoDestination selectedDest = NanoDestination.home;
    String? submittedQuery;
    bool voiceTapped = false;
    bool avatarTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Center(
                child: NanoMultiUseNavBar(
                  selected: selectedDest,
                  onDestinationSelected: (dest) {
                    setState(() => selectedDest = dest);
                  },
                  onSearch: (query) => submittedQuery = query,
                  onVoice: () => voiceTapped = true,
                  onAvatarTap: () => avatarTapped = true,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verificar los 6 destinos
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Modelos'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Automatización'), findsOneWidget);

    // 2. Verificar placeholder de búsqueda
    expect(
      find.text('Buscar, conversar o ejecutar en Nano AI...'),
      findsOneWidget,
    );

    // 3. Selección animada de Chat
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(selectedDest, equals(NanoDestination.chat));

    // 4. Selección animada de Automatización
    await tester.tap(find.text('Automatización'));
    await tester.pumpAndSettle();
    expect(selectedDest, equals(NanoDestination.automation));

    // 5. Escritura y envío en barra de búsqueda
    await tester.enterText(
      find.byType(TextField),
      'htop',
    );
    await tester.pump();
    expect(find.byTooltip('Limpiar texto'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submittedQuery, equals('htop'));

    // 6. Botón de micrófono / voz
    await tester.tap(find.bySemanticsLabel('Voz'));
    await tester.pump();
    expect(voiceTapped, isTrue);

    // 7. Botón de avatar / asistente
    await tester.tap(find.bySemanticsLabel('Asistente Nano AI'));
    await tester.pump();
    expect(avatarTapped, isTrue);
  });
}
