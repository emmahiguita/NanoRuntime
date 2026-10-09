part of 'conversation_detail_sheet.dart';

/// [ConversationDetailComposerView] — Barra de escritura unificada limpia estilo ChatGPT / Gemini / iOS.
///
/// QUÉ HACE:
/// Integra en una única cápsula fluida y continua:
/// [Clip] -> [Campo de texto expandido sin cajas internas] -> [IA ✨] -> [Enviar ↑].
///
/// CÓMO FUNCIONA:
/// - Un único contenedor exterior con borde sutil y fondo de cristal esmerilado.
/// - El TextField fluye directamente dentro de la cápsula sin contenedores duplicados ni marcos dobles.
/// - Los botones se anclan a las esquinas inferiores (`CrossAxisAlignment.end`) al escribir varias líneas.
///
/// POR QUÉ:
/// Elimina el bug de malformación/doble borde y ofrece la experiencia limpia de ChatGPT o Gemini (< 150 líneas).
extension ConversationDetailComposerView on _ConversationDetailSheetState {
  Widget _buildComposerRow(
    AutomationVisualPalette visual, {
    required bool isLandscape,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _inputController,
      builder: (context, value, _) => LayoutBuilder(
        builder: (context, constraints) {
          final isDark = visual.isDark;
          final narrow = constraints.maxWidth < 370;
          final controlSize = narrow ? 40.0 : 44.0;
          final hasText = value.text.trim().isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: controlSize + 10),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172033) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFDCE4EC),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildComposerIconButton(
                  icon: CupertinoIcons.paperclip,
                  tooltip: 'Adjuntar archivo',
                  isDark: isDark,
                  onTap: _busy ? null : _showAttachmentMenu,
                  size: controlSize,
                  iconSize: 20,
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: isLandscape ? 2 : 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    autocorrect: true,
                    enableSuggestions: true,
                    cursorColor: visual.accent,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF172033),
                      fontFamily: 'Inter',
                      fontFamilyFallback: ConversationDetailSheet._sfFallback,
                      fontSize: narrow ? 14 : 15,
                      height: 1.32,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje',
                      hintStyle: TextStyle(
                        color: visual.textMuted,
                        fontFamily: 'Inter',
                        fontFamilyFallback: ConversationDetailSheet._sfFallback,
                        fontSize: narrow ? 14 : 15,
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(6, 11, 6, 11),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                _buildComposerIconButton(
                  icon: CupertinoIcons.sparkles,
                  tooltip: 'Sugerir con IA',
                  iconColor: isDark
                      ? const Color(0xFF7DD3FC)
                      : const Color(0xFF0369A1),
                  isDark: isDark,
                  onTap: _busy
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _generateAiSuggestion();
                        },
                  size: controlSize,
                  iconSize: 18,
                ),
                const SizedBox(width: 2),
                _buildCompactSendButton(
                  visual,
                  enabled: hasText && !_busy,
                  size: controlSize,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposerIconButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback? onTap,
    Color? iconColor,
    double size = 32,
    double iconSize = 17,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color:
                    iconColor ??
                    (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSendButton(
    AutomationVisualPalette visual, {
    required bool enabled,
    required double size,
  }) {
    final activeColor = visual.isDark
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF0878D1);
    return Semantics(
      label: 'Enviar respuesta',
      button: true,
      enabled: enabled,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.24),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: enabled
              ? activeColor
              : (visual.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFEEF2F6)),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    _sendReply();
                  }
                : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.arrow_up,
                        size: 19,
                        color: enabled
                            ? Colors.white
                            : visual.textMuted.withValues(alpha: 0.55),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
