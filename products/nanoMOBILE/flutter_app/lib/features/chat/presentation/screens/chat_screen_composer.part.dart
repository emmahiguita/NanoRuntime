part of 'chat_screen.dart';

// QUÉ HACE:
// Barra de redacción de mensajes profesional, limpia y moderna con acabado Frosted Liquid Glass.
//
// CÓMO FUNCIONA:
// - Despliega un pill flotante con filtro de desenfoque ambiental (`BackdropFilter`) y bordes esmerilados.
// - Integra botón de adjuntos circular, campo de texto dinámico auto-expandible y micrófono de dictado.
// - El botón de envío se activa con texto real mediante micro-interacción y cambia a detención al generar.
// - Totalmente adaptativo en modo horizontal (Landscape) y seguro contra el error de "No Overlay".
//
// POR QUÉ:
// Resuelve la petición de sustituir la barra anticuada por un diseño limpio, perfecto y profesional,
// cumpliendo estrictamente con SOLID, Material Expressive 3 y el límite de 200 líneas por archivo.
extension _ChatScreenComposer on _ChatScreenState {
  /// QUÉ HACE: Construye la barra de composición flotante con diseño ergonómico de alta gama.
  Widget _buildComposerBar(
    BuildContext context,
    ChatState state,
    ChatNotifier notifier,
    NanoColors colors, {
    bool compact = false,
  }) {
    final isDark = colors is NanoDarkColors;
    final hasText = _textController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tira de archivos adjuntos (si existen)
        if (state.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _AttachmentPillsStrip(
              attachments: state.attachments,
              onRemove: notifier.removeAttachment,
            ),
          ),

        // Contenedor principal flotante con área segura inferior
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              2,
              compact ? 12 : 16,
              compact ? 6 : 10,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xD90F172A) // Slate oscuro translúcido
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 1. Botón circular para adjuntar archivos o fotos
                      Semantics(
                        label: 'Adjuntar documento o imagen',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: state.generating ? null : _attachFile,
                            child: SizedBox(
                              width: compact ? 34 : 38,
                              height: compact ? 34 : 38,
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                color: colors.onSurface.withValues(alpha: 0.65),
                                size: compact ? 20 : 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // 2. Campo de texto limpio con tipografía Inter y auto-expansión
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: compact ? 3 : 5,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: compact ? 13.5 : 14.5,
                              color: colors.onSurface,
                              letterSpacing: -0.1,
                            ),
                            cursorColor: colors.accent,
                            decoration: InputDecoration(
                              hintText: state.generating
                                  ? 'Pensando respuesta…'
                                  : 'Escribe un mensaje a Nano AI…',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: compact ? 13.5 : 14.5,
                                fontWeight: FontWeight.w400,
                                color: colors.onSurface.withValues(alpha: 0.40),
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: compact ? 6 : 8,
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty && !state.generating) {
                                notifier.send(text.trim());
                                _textController.clear();
                                setState(() => _dictatedText = '');
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // 3. Botón de dictado por voz interactivo
                      _buildComposerMicButton(compact: compact, colors: colors),
                      const SizedBox(width: 4),

                      // 4. Botón Enviar / Detener con micro-interacción y estado reactivo
                      _buildComposerSendButton(
                        isGenerating: state.generating,
                        hasText: hasText,
                        compact: compact,
                        isDark: isDark,
                        colors: colors,
                        onStop: notifier.stop,
                        onSend: notifier.send,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
