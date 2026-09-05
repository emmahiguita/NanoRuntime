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

    // Verify all 6 destination labels are present
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Modelos'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Automatización'), findsOneWidget);

    // Verify search hint is present
    expect(find.text('Describe qué quieres automatizar...'), findsOneWidget);

    // Tap on 'Chat' destination
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(selectedDest, equals(NanoDestination.chat));

    // Tap on 'Automatización' destination
    await tester.tap(find.text('Automatización'));
    await tester.pumpAndSettle();
    expect(selectedDest, equals(NanoDestination.automation));

    // Test text typing and submit
    await tester.enterText(
      find.byType(TextField),
      'Abrir terminal y correr update',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submittedQuery, equals('Abrir terminal y correr update'));

    // Test voice button
    await tester.tap(find.bySemanticsLabel('Voz'));
    await tester.pump();
    expect(voiceTapped, isTrue);

    // Test avatar button
    await tester.tap(find.bySemanticsLabel('Asistente Nano AI'));
    await tester.pump();
    expect(avatarTapped, isTrue);
  });
}
