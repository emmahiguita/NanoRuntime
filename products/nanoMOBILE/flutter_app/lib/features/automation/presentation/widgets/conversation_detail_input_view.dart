part of 'conversation_detail_sheet.dart';

/// [ConversationDetailInputView]
///
/// QUÉ HACE:
/// Renderiza la barra inferior de entrada de texto, chips de sugerencias generadas
/// por la IA local, botón de adjuntos y botón de envío hacia WhatsApp.
///
/// CÓMO FUNCIONA:
/// 1. Botón "Sugerir con IA": desencadena `_generateAiSuggestion` con faits de negocio.
/// 2. Carrusel horizontal de sugerencias inteligentes con texto clickeable.
/// 3. Botón de clip para desplegar menú de adjuntos (imágenes, PDFs, formularios).
/// 4. Campo de texto autoexpandible y botón de despacho con animación de carga.
/// 5. En horizontal (landscape), reduce los márgenes e insets para evitar que el teclado
///    tape el campo de escritura.
///
/// POR QUÉ:
/// Ofrece una experiencia fluida de redacción rápida sin salir de Nano y sin superar
/// el límite estricto de 200 líneas de código.
extension ConversationDetailInputView on _ConversationDetailSheetState {
  Widget _buildBottomActionBar(AutomationVisualPalette visual) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            isLandscape ? 4 : 8,
            12,
            isLandscape ? 6 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.isDark ? 0.04 : 0.40),
            border: Border(
              top: BorderSide(
                color: visual.isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0x33CBD5E1),
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSuggestionActions(visual, isLandscape: isLandscape),
              const SizedBox(height: 8),
              _buildComposerRow(visual, isLandscape: isLandscape),
            ],
          ),
        ),
      ),
    );
  }
}
