/// ChatComposer — barra de entrada del chat (extraída de chat_screen.dart por
/// Clean Architecture/SOLID: cada widget cohesivo vive en su propio archivo).
///
/// Widget de presentación: recibe controller, callbacks y estado por parámetros;
/// no conoce el ChatNotifier ni la orquestación. Lógica intacta (solo movida).
///
/// Card de escritura profesional (ChatGPT/Gemini): header de estado + campo de
/// texto amplio y multilínea + acciones organizadas sin solapamiento.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/features/automation/engine/voice/voice_runtime.dart';
import 'package:nanoai/features/automation/presentation/widgets/nano_voice_orb.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.generating,
    required this.listening,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onMic,
    required this.onMinimize,
    required this.compact,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool generating;
  final bool listening;
  final List<ChatAttachment> attachments;
  final void Function(String) onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onMinimize;
  final bool compact;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    // Desktop/Web: Enter envía, Shift+Enter inserta salto de línea.
    // En móvil, la tecla "enviar" del teclado dispara onSubmitted.
    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final key = event.logicalKey;
      if (key != LogicalKeyboardKey.enter &&
          key != LogicalKeyboardKey.numpadEnter) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      _trySend();
      return KeyEventResult.handled;
    };
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  /// Envío seguro: solo si el composer está habilitado y hay texto.
  void _trySend() {
    if (widget.enabled && _hasText) {
      widget.onSend();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    // UI-REV-10: el header solo vive cuando tiene contenido (estado de voz/
    // generación o campo enfocado). Sin foco ni estado la card es SOLO la fila
    // de escritura — cero espacio muerto encima del campo.
    final showHeader = widget.listening || widget.generating || _isFocused;

    return NanoOpticalSurface(
      geometry: NanoSurfaceGeometry.roundedRectangle,
      borderRadius: 28,
      blurSigma: widget.compact ? 16.0 : 22.0,
      borderStrength: _isFocused ? 1.0 : 0.80,
      // El campo de texto es una superficie de trabajo: la caustica movil no
      // debe atravesar las letras. En escritorio se conserva el barrido al
      // estar inactivo; en movil se priorizan legibilidad y frame time.
      reflectionStrength: _isFocused ? 0.42 : 0.32,
      depth: 1.15,
      tilt: !widget.compact,
      autoReflect: !widget.compact && !_isFocused,
      accent: _isFocused
          ? (isDark ? colors.accent : colors.accentCyan)
          : (isDark ? colors.accent.withValues(alpha: 0.7) : colors.accentSky),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header sutil: estado (escuchando/generando) + minimizar a la
          // derecha. Colapsa a 0 con AnimatedSize cuando no hay nada que
          // mostrar — el espacio es del campo de texto.
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showHeader
                ? SizedBox(
                    height: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            widget.listening
                                ? 'Escuchando…'
                                : (widget.generating ? 'Generando…' : ''),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: widget.listening
                                  ? colors.accent
                                  : colors.onSurfaceVariant.withValues(
                                      alpha: 0.55,
                                    ),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Minimizar barra',
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                            child: InkWell(
                              key: const ValueKey('chat_composer_minimize'),
                              borderRadius: BorderRadius.circular(99),
                              onTap: widget.onMinimize,
                              child: SizedBox(
                                width: 28,
                                height: 24,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.50,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Chips de adjuntos (solo si hay).
          if (widget.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
              child: SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final attachment = widget.attachments[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 13,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              attachment.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.onSurface.withValues(alpha: 0.90),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                widget.onRemoveAttachment(attachment.name),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: colors.onSurface.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Fila de escritura: [mic] [ CAMPO AMPLIO ] [attach] [enviar].
          // UI-REV-11: el campo es el protagonista absoluto — adjuntar se
          // mueve a la derecha (patrón Gemini) y cede al texto todo el ancho.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón Mic / Dictado
              Tooltip(
                message: 'Dictado por voz',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: NanoVoiceOrb(
                    state: widget.listening
                        ? VoiceSessionState.listening
                        : VoiceSessionState.idle,
                    onTap: widget.onMic,
                    size: widget.compact ? 34 : 38,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Campo de texto: protagonista de la card. Ocupa todo el ancho
              // libre y su padding vertical mínimo (8) lo alinea con los
              // botones de 38px sin aire muerto.
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: widget.compact ? 4 : 6,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _trySend(),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Inter',
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.listening
                        ? 'Escuchando voz…'
                        : 'Escribe un mensaje…',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.52),
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Adjuntar — a la derecha del campo, junto al enviar
              // (patrón Gemini): todo el ancho libre es del texto.
              Tooltip(
                message: 'Adjuntar archivo',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.onAttach,
                    child: SizedBox(
                      width: widget.compact ? 28 : 30,
                      height: widget.compact ? 34 : 40,
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: colors.onSurface.withValues(alpha: 0.55),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Botón Enviar / Detener (vidrio + gradiente dinámico)
              Tooltip(
                message: widget.generating ? 'Detener generación' : 'Enviar',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: widget.generating
                        ? widget.onStop
                        : (_hasText && widget.enabled ? widget.onSend : null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: widget.compact ? 38 : 40,
                      height: widget.compact ? 38 : 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: widget.generating
                            ? null
                            : (_hasText && widget.enabled
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isDark
                                          ? [colors.accent, colors.accentMint]
                                          : [colors.primary, colors.accentSky],
                                    )
                                  : null),
                        color: widget.generating
                            ? colors.danger.withValues(alpha: 0.18)
                            : (_hasText && widget.enabled
                                  ? null
                                  : colors.onSurface.withValues(alpha: 0.08)),
                        border: Border.all(
                          color: widget.generating
                              ? colors.danger.withValues(alpha: 0.65)
                              : (_hasText && widget.enabled
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : colors.onSurface.withValues(alpha: 0.12)),
                          width: 0.9,
                        ),
                        boxShadow: _hasText && widget.enabled
                            ? [
                                BoxShadow(
                                  color:
                                      (isDark ? colors.accent : colors.primary)
                                          .withValues(
                                            alpha: isDark ? 0.35 : 0.22,
                                          ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          widget.generating
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                          size: 20,
                          color: widget.generating
                              ? colors.danger
                              : (_hasText && widget.enabled
                                    ? (isDark
                                          ? const Color(0xFF000000)
                                          : Colors.white)
                                    : colors.onSurface.withValues(alpha: 0.30)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
