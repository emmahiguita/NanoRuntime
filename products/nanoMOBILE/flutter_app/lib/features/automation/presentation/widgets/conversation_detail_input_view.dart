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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            isLandscape ? 4 : 8,
            12,
            MediaQuery.of(context).viewInsets.bottom + (isLandscape ? 6 : 12),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: visual.isDark ? 0.04 : 0.40),
            border: Border(
              top: BorderSide(
                color: visual.isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0x33CBD5E1),
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _generateAiSuggestion,
                    icon: const Icon(CupertinoIcons.sparkles, size: 13),
                    label: const Text(
                      'Sugerir con IA',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: BorderSide(color: const Color(0xFF007AFF).withValues(alpha: 0.45)),
                      backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final text = _suggestions[index];
                      final isSelected = _inputController.text.trim() == text.trim();
                      return ActionChip(
                        avatar: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.chat_bubble_outline_rounded,
                          size: 12,
                          color: isSelected ? const Color(0xFF007AFF) : visual.textMuted,
                        ),
                        label: Text(
                          'Opción ${index + 1}: ${text.length > 24 ? "${text.substring(0, 24)}..." : text}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF007AFF) : visual.text,
                          ),
                        ),
                        backgroundColor: isSelected ? const Color(0xFF007AFF).withValues(alpha: 0.14) : (visual.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                        side: BorderSide(color: isSelected ? const Color(0xFF007AFF).withValues(alpha: 0.50) : (visual.isDark ? Colors.white12 : Colors.black12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => _safeSetState(() => _inputController.text = text),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Semantics(
                    label: 'Adjuntar documento, imagen, PDF o formulario',
                    button: true,
                    child: IconButton(
                      onPressed: _busy ? null : _showAttachmentMenu,
                      icon: Icon(CupertinoIcons.paperclip, color: visual.accent, size: isLandscape ? 18 : 20),
                      style: IconButton.styleFrom(
                        backgroundColor: visual.accent.withValues(alpha: 0.12),
                        padding: EdgeInsets.all(isLandscape ? 6 : 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_busy,
                      maxLines: isLandscape ? 2 : 3,
                      minLines: 1,
                      style: TextStyle(color: visual.text, fontFamily: 'Inter', fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu respuesta...',
                        hintStyle: TextStyle(color: visual.textMuted, fontFamily: 'Inter', fontSize: 13.5),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.85),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: visual.isDark ? 0.18 : 0.50)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _busy ? null : _sendReply,
                    child: Container(
                      width: isLandscape ? 36 : 40,
                      height: isLandscape ? 36 : 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF007AFF), Color(0xFF0056C6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : Icon(CupertinoIcons.arrow_up, color: Colors.white, size: isLandscape ? 17 : 19),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
