import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/nano_runtime_api.dart';
import 'nano_destination.dart';
import 'nano_glyph.dart';
import 'nano_nav_tokens.dart';
import 'nano_search_dispatcher.dart';
import 'nano_universal_input.dart';

/// Barra de navegación multifunción cósmica flotante de Nano AI.
///
/// Arquitectura SOLID reutilizable: actúa como la barra universal de comando,
/// escritura y navegación para todas las pantallas de la aplicación.
class NanoMultiUseNavBar extends StatefulWidget {
  const NanoMultiUseNavBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    this.inputConfig,
    this.onSearch,
    this.onVoice,
    this.onAvatarTap,
    this.searchHint = 'Buscar, conversar o ejecutar en Nano AI...',
    this.brightness,
    this.compact = false,
    this.showFeather = true,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final NanoUniversalInputConfig? inputConfig;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onVoice;
  final VoidCallback? onAvatarTap;
  final String searchHint;
  final Brightness? brightness;
  final bool compact;
  final bool showFeather;

  @override
  State<NanoMultiUseNavBar> createState() => _NanoMultiUseNavBarState();
}

class _NanoMultiUseNavBarState extends State<NanoMultiUseNavBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  // NAV-BAR-FIX-05 — dictado por voz por defecto de la barra. Si la pantalla
  // no define su propio onVoice (Chat lo define para su conversación
  // continua), la barra dicta directo: parciales escriben en el campo en
  // vivo y el resultado final queda listo para enviar. Antes el fallback
  // navegaba a /automation — el mic no hacía nada útil fuera de Chat.
  bool _dictating = false;
  StreamSubscription<String>? _voiceSub;

  @override
  void initState() {
    super.initState();
    if (widget.inputConfig?.initialText != null) {
      _controller.text = widget.inputConfig!.initialText!;
      _hasText = _controller.text.trim().isNotEmpty;
    }
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    _controller.addListener(() {
      final text = _controller.text;
      final hasTextNow = text.trim().isNotEmpty;
      if (hasTextNow != _hasText && mounted) {
        setState(() => _hasText = hasTextNow);
      }
      widget.inputConfig?.onChanged?.call(text);
    });
  }

  @override
  void didUpdateWidget(covariant NanoMultiUseNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextInit = widget.inputConfig?.initialText;
    final oldInit = oldWidget.inputConfig?.initialText;
    if (nextInit != null && nextInit != oldInit && nextInit != _controller.text) {
      _controller.text = nextInit;
      _hasText = nextInit.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchSubmit([String? value]) {
    final query = (value ?? _controller.text).trim();
    if (query.isNotEmpty) {
      HapticFeedback.mediumImpact();
      final config = widget.inputConfig;
      if (config?.onSubmit != null) {
        config!.onSubmit!(query);
      } else if (widget.onSearch != null) {
        widget.onSearch!(query);
      } else {
        NanoSearchDispatcher.dispatch(context, query);
      }
      if (config?.clearOnSubmit ?? true) {
        _controller.clear();
        setState(() => _hasText = false);
      }
      // NAV-BAR-FIX-01 — conversación continua: el chat mantiene el foco y
      // el teclado abiertos tras enviar; las demás pantallas lo cierran.
      if (!(config?.keepFocusOnSubmit ?? false)) {
        _focusNode.unfocus();
      }
    }
  }

  /// Dictado por voz real de la barra (misma API del chat: canal
  /// `com.nanoai/speech`). Escribe los parciales en el campo en vivo; el
  /// resultado final queda en el campo y el usuario decide cuándo enviar.
  /// Errores honestos, nunca excepción suelta.
  Future<void> _toggleDefaultDictation() async {
    if (_dictating) {
      setState(() => _dictating = false);
      await _voiceSub?.cancel();
      _voiceSub = null;
      await NanoRuntimeApi.instance.stopSpeech();
      return;
    }
    setState(() => _dictating = true);
    _voiceSub = NanoRuntimeApi.instance.voicePartialStream.listen((partial) {
      if (!mounted || !_dictating) return;
      _controller.text = partial;
      _controller.selection = TextSelection.collapsed(offset: partial.length);
      setState(() => _hasText = partial.trim().isNotEmpty);
    });
    final text = await NanoRuntimeApi.instance.startVoiceRecognition();
    await _voiceSub?.cancel();
    _voiceSub = null;
    if (!mounted) return;
    setState(() => _dictating = false);
    if (text != null && text.trim().isNotEmpty) {
      _controller.text = text.trim();
      _controller.selection = TextSelection.collapsed(
        offset: text.trim().length,
      );
      setState(() => _hasText = true);
    } else if (_controller.text.trim().isEmpty) {
      // Sin parciales y sin resultado: aviso honesto en vez de silencio.
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo reconocer el audio. Inténtalo de nuevo.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness ?? Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final config = widget.inputConfig;
    final effectiveHint = config?.hint ?? widget.searchHint;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < 480 || widget.compact;
        final radius = narrow ? 26.0 : 32.0;

        return Semantics(
          container: true,
          label: 'Barra cósmica multifunción Nano AI',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: NanoNavTokens.cyan.withValues(alpha: isDark ? .28 : .14),
                  blurRadius: _focused ? 32 : 22,
                  spreadRadius: _focused ? 1.5 : -1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: NanoNavTokens.accentBlue.withValues(alpha: isDark ? .32 : .12),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .48 : .10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF00A1838),
                              Color(0xEB07122C),
                              Color(0xF203091B),
                            ],
                            stops: [0.0, 0.48, 1.0],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xF5FFFFFF),
                              Color(0xECF0F6FF),
                              Color(0xDFE3EEFF),
                            ],
                          ),
                    border: Border.all(
                      color: _focused
                          ? NanoNavTokens.cyan.withValues(alpha: .95)
                          : (isDark
                              ? NanoNavTokens.electricBlue.withValues(alpha: .68)
                              : Colors.white.withValues(alpha: .90)),
                      width: _focused ? 1.3 : 1.1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (widget.showFeather)
                        Positioned(
                          right: -12,
                          top: -16,
                          width: narrow ? 150 : 210,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: isDark ? .42 : .18,
                              child: Image.asset(
                                'assets/nano/nano_feather.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        left: 20,
                        right: 20,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: isDark ? 0.35 : 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 10 : 13,
                          narrow ? 9 : 11,
                          narrow ? 10 : 13,
                          narrow ? 8 : 10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SearchRow(
                              brightness: b,
                              controller: _controller,
                              focusNode: _focusNode,
                              hint: effectiveHint,
                              hasText: _hasText,
                              isGenerating: config?.isGenerating ?? false,
                              onStop: config?.onStop,
                              onAttach: config?.onAttach,
                              onSubmitted: _handleSearchSubmit,
                              onClear: () {
                                _controller.clear();
                                setState(() => _hasText = false);
                              },
                              // NAV-BAR-FIX-05 — si la pantalla no define
                              // voz propia, la barra dicta directo al campo.
                              onVoice:
                                  config?.onVoice ??
                                  widget.onVoice ??
                                  _toggleDefaultDictation,
                              listening:
                                  (config?.isListening ?? false) || _dictating,
                              onAvatarTap: widget.onAvatarTap,
                              compact: narrow,
                            ),
                            SizedBox(height: narrow ? 6 : 9),
                            _DestinationsDock(
                              brightness: b,
                              selected: widget.selected,
                              compact: narrow,
                              onSelected: (d) {
                                HapticFeedback.selectionClick();
                                widget.onDestinationSelected(d);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.brightness,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.hasText,
    required this.isGenerating,
    required this.onStop,
    required this.onAttach,
    required this.onSubmitted,
    required this.onClear,
    required this.onVoice,
    required this.listening,
    required this.onAvatarTap,
    required this.compact,
  });

  final Brightness brightness;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool hasText;
  final bool isGenerating;
  final VoidCallback? onStop;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onVoice;
  final bool listening;
  final VoidCallback? onAvatarTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final text = NanoNavTokens.text(brightness);
    final muted = NanoNavTokens.textMuted(brightness);

    return Row(
      children: [
        // NAV-BAR-FIX-02 — el orbe es el acceso al asistente: en el propio
        // chat no aporta (ya estás ahí) y le robaba al campo el espacio que
        // hoy es el protagonista. Solo se muestra si la pantalla le da uso.
        if (onAvatarTap != null) ...[
          _OwlAvatarOrb(
            brightness: brightness,
            size: compact ? 46 : 52,
            onTap: onAvatarTap,
          ),
          SizedBox(width: compact ? 8 : 11),
        ],
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            // NAV-BAR-FIX-02 — sin altura fija: el campo crece hasta 4 líneas
            // (lógica completa de escritura) y la card crece con él. La lupa
            // decorativa salió: era ancho robado al texto (el hint ya guía).
            constraints: BoxConstraints(minHeight: compact ? 44 : 48),
            decoration: BoxDecoration(
              color: dark
                  ? const Color(0x750D1D42)
                  : const Color(0xE0FFFFFF),
              borderRadius: BorderRadius.circular(compact ? 22 : 24),
              border: Border.all(
                color: focusNode.hasFocus
                    ? NanoNavTokens.cyan.withValues(alpha: .92)
                    : (dark
                        ? const Color(0x6642B7FF)
                        : const Color(0x403B82F6)),
                width: focusNode.hasFocus ? 1.2 : .85,
              ),
              boxShadow: focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: NanoNavTokens.cyan.withValues(alpha: .30),
                        blurRadius: 16,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(width: compact ? 10 : 12),

                // Campo de texto universal (multilínea que crece)
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: compact ? 3 : 5,
                    style: TextStyle(
                      color: text,
                      fontSize: compact ? 12.8 : 13.8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .05,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: muted.withValues(alpha: .80),
                        fontSize: compact ? 11.6 : 12.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),

                // Botón de adjuntar archivo si la pantalla lo soporta
                if (onAttach != null)
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: compact ? 18 : 20,
                      color: muted,
                    ),
                    onPressed: onAttach,
                    tooltip: 'Adjuntar archivo',
                    splashRadius: 18,
                  ),

                // Botón limpiar cuando hay texto
                if (hasText)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: compact ? 16 : 18,
                      color: muted,
                    ),
                    onPressed: onClear,
                    tooltip: 'Limpiar texto',
                    splashRadius: 18,
                  ),

                // Botón de detener generación O micrófono de voz
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: isGenerating
                      ? _StopButton(
                          size: compact ? 34 : 38,
                          onTap: onStop,
                        )
                      : hasText
                          ? _SendActionButton(
                              size: compact ? 34 : 38,
                              onTap: () => onSubmitted?.call(controller.text),
                            )
                          : _VoiceOrbButton(
                              size: compact ? 34 : 38,
                              onTap: onVoice,
                              listening: listening,
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SendActionButton extends StatelessWidget {
  const _SendActionButton({
    required this.size,
    required this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Enviar',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap?.call();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: NanoNavTokens.sendButtonGradient,
              border: Border.all(
                color: Colors.white.withValues(alpha: .70),
                width: .9,
              ),
              boxShadow: [
                BoxShadow(
                  color: NanoNavTokens.accentBlue.withValues(alpha: .55),
                  blurRadius: 14,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Center(
              child: NanoGlyph(
                type: NanoGlyphType.arrowForward,
                color: Colors.white,
                size: size * .50,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.size,
    required this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Detener respuesta',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap?.call();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .80),
                width: .9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: .6),
                  blurRadius: 14,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwlAvatarOrb extends StatelessWidget {
  const _OwlAvatarOrb({
    required this.brightness,
    required this.size,
    required this.onTap,
  });

  final Brightness brightness;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Asistente Nano AI',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: NanoNavTokens.activeGradient,
                boxShadow: [
                  BoxShadow(
                    color: NanoNavTokens.cyan.withValues(alpha: .50),
                    blurRadius: 16,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(1.8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brightness == Brightness.dark
                      ? const Color(0xFF040A18)
                      : Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/nano/nano_owl.png',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.15),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: size * .24,
                height: size * .24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NanoNavTokens.neonGreen,
                  border: Border.all(
                    color: brightness == Brightness.dark
                        ? const Color(0xFF030B20)
                        : Colors.white,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NanoNavTokens.neonGreen.withValues(alpha: .95),
                      blurRadius: 8,
                      spreadRadius: .8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceOrbButton extends StatefulWidget {
  const _VoiceOrbButton({
    required this.size,
    required this.onTap,
    required this.listening,
  });

  final double size;
  final VoidCallback? onTap;
  final bool listening;

  @override
  State<_VoiceOrbButton> createState() => _VoiceOrbButtonState();
}

class _VoiceOrbButtonState extends State<_VoiceOrbButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: .92,
      upperBound: 1.06,
    );
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _VoiceOrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening && !oldWidget.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && oldWidget.listening) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final listening = widget.listening;

    return Semantics(
      button: true,
      // NAV-BAR-FIX-05 — el orbe dice la VERDAD: mientras escucha es un
      // botón de detener (rojo, pulso); en reposo es el micrófono. Antes
      // el botón siempre parecía "mic disponible" aunque ya grabara.
      label: listening ? 'Detener dictado' : 'Voz',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onTap?.call();
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: listening ? _pulse.value : 1.0,
              child: child,
            ),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: listening
                    ? const RadialGradient(
                        center: Alignment(-.25, -.28),
                        radius: .95,
                        colors: [
                          Color(0xFFFF8A80),
                          Color(0xFFEF4444),
                          Color(0xFFDC2626),
                          Color(0xFF7F1D1D),
                        ],
                        stops: [0.0, .36, .72, 1.0],
                      )
                    : const RadialGradient(
                        center: Alignment(-.25, -.28),
                        radius: .95,
                        colors: [
                          Color(0xFF5CE7FF),
                          Color(0xFF2A7FFF),
                          Color(0xFF7058FF),
                          Color(0xFF1B1C65),
                        ],
                        stops: [0.0, .36, .72, 1.0],
                      ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .70),
                  width: .9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: listening
                        ? Colors.red.withValues(alpha: .60)
                        : NanoNavTokens.cyan.withValues(alpha: .45),
                    blurRadius: 14,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Center(
                child: listening
                    ? const Icon(
                        Icons.stop_rounded,
                        color: Colors.white,
                        size: 20,
                      )
                    : NanoGlyph(
                        type: NanoGlyphType.microphone,
                        color: Colors.white,
                        size: size * .50,
                        strokeWidth: 2.0,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationsDock extends StatelessWidget {
  const _DestinationsDock({
    required this.brightness,
    required this.selected,
    required this.onSelected,
    required this.compact,
  });

  final Brightness brightness;
  final NanoDestination selected;
  final ValueChanged<NanoDestination> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = selected.index;
    final count = NanoDestination.values.length;

    return Stack(
      children: [
        Row(
          children: [
            for (final d in NanoDestination.values)
              Expanded(
                child: _DestinationTab(
                  destination: d,
                  selected: selected == d,
                  brightness: brightness,
                  compact: compact,
                  onTap: () => onSelected(d),
                ),
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / count;
              final indicatorWidth = compact ? 22.0 : 28.0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  -1.0 + (selectedIndex * (2.0 / (count - 1))),
                  0,
                ),
                child: Container(
                  width: tabWidth,
                  alignment: Alignment.center,
                  child: Container(
                    width: indicatorWidth,
                    height: 2.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: NanoNavTokens.cyan,
                      boxShadow: [
                        BoxShadow(
                          color: NanoNavTokens.cyan.withValues(alpha: .95),
                          blurRadius: 8,
                          spreadRadius: .5,
                        ),
                        BoxShadow(
                          color: NanoNavTokens.accentBlue.withValues(alpha: .65),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DestinationTab extends StatelessWidget {
  const _DestinationTab({
    required this.destination,
    required this.selected,
    required this.brightness,
    required this.compact,
    required this.onTap,
  });

  final NanoDestination destination;
  final bool selected;
  final Brightness brightness;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = NanoNavTokens.textMuted(brightness);
    final active = brightness == Brightness.dark
        ? NanoNavTokens.cyan
        : const Color(0xFF0284C7);

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 3 : 4,
            horizontal: 1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: selected ? 1.08 : 1.0,
                child: NanoGlyph(
                  type: destination.glyph,
                  color: selected ? active : muted,
                  size: compact ? 20 : 22,
                  strokeWidth: selected ? 2.15 : 1.80,
                  glow: selected,
                ),
              ),
              SizedBox(height: compact ? 2 : 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? active : muted,
                    fontSize: compact ? 8.8 : 9.8,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -.05,
                    shadows: selected
                        ? [
                            Shadow(
                              color: active.withValues(alpha: .6),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }
}
