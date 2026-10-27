import 'package:flutter/material.dart';

/// Organiza el perfil en tarjetas con un único desplazamiento.
/// Conserva espacio para teclado y gestos, incluso en ventanas pequeñas.
class ProfileEditorLayout extends StatelessWidget {
  final Widget identity, personal, location, contact, save, accountActions;
  const ProfileEditorLayout({
    super.key,
    required this.identity,
    required this.personal,
    required this.location,
    required this.contact,
    required this.save,
    required this.accountActions,
  });

  /// Dos columnas solo cuando caben las tarjetas y el tamaño de texto elegido.
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final wide = constraints.maxWidth >= 760 * scale;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(context, personal),
            const SizedBox(height: 16),
            _card(context, contact),
            const SizedBox(height: 16),
            _card(context, location),
          ],
        );
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(context, identity),
            const SizedBox(height: 16),
            save,
            const SizedBox(height: 8),
            accountActions,
          ],
        );
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: summary),
                        const SizedBox(width: 20),
                        Expanded(child: details),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _card(context, identity),
                        const SizedBox(height: 16),
                        details,
                        const SizedBox(height: 20),
                        save,
                        const SizedBox(height: 8),
                        accountActions,
                      ],
                    ),
            ),
          ),
        );
      },
    ),
  );

  /// Superficies Material compartidas, sin filtros de desenfoque por campo.
  Widget _card(BuildContext context, Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
