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
/// Diseño iOS Liquid-Glass optimizado: campo de búsqueda a lo largo completo
/// sin solapes, iconos compactos y dock de 6 pestañas con indicador fluido.
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
    this.transparent = false,
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

  /// Si es true, el dock adopta una presencia ligera sin caja opaca para
  /// que el fondo o los controles inferiores (Terminal, etc.) no colisionen.
  final bool transparent;

  @override
  State<NanoMultiUseNavBar> createState() => _NanoMultiUseNavBarState();
}

class _NanoMultiUseNavBarState extends State<NanoMultiUseNavBar> {
  final _internalController = TextEditingController();
  final _internalFocusNode = FocusNode();

  TextEditingController get _controller =>
      widget.inputConfig?.controller ?? _internalController;
  FocusNode get _focusNode =>
      widget.inputConfig?.focusNode ?? _internalFocusNode;

  bool _focused = false;
  bool _hasText = false;

  bool _dictating = false;
  StreamSubscription<String>? _voiceSub;

  void _onFocus() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  void _onText() {
    final text = _controller.text;
    final hasTextNow = text.trim().isNotEmpty;
    if (hasTextNow != _hasText && mounted) {
      setState(() => _hasText = hasTextNow);
    }
    widget.inputConfig?.onChanged?.call(text);
  }

  @override
  void initState() {
    super.initState();
    if (widget.inputConfig?.initialText != null) {
      _controller.text = widget.inputConfig!.initialText!;
      _hasText = _controller.text.trim().isNotEmpty;
    }
    _focusNode.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant NanoMultiUseNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFn = oldWidget.inputConfig?.focusNode ?? _internalFocusNode;
    final newFn = widget.inputConfig?.focusNode ?? _internalFocusNode;
    if (oldFn != newFn) {
      oldFn.removeListener(_onFocus);
      newFn.addListener(_onFocus);
      _focused = newFn.hasFocus;
    }

    final oldCtl = oldWidget.inputConfig?.controller ?? _internalController;
    final newCtl = widget.inputConfig?.controller ?? _internalController;
    if (oldCtl != newCtl) {
      oldCtl.removeListener(_onText);
      newCtl.addListener(_onText);
      _hasText = newCtl.text.trim().isNotEmpty;
    }

    final nextInit = widget.inputConfig?.initialText;
    final oldInit = oldWidget.inputConfig?.initialText;
    if (nextInit != null &&
        nextInit != oldInit &&
        nextInit != _controller.text) {
      _controller.text = nextInit;
      _hasText = nextInit.trim().isNotEmpty;
    } else if (widget.selected != oldWidget.selected &&
        (widget.inputConfig?.initialText == null ||
            widget.inputConfig!.initialText!.isEmpty)) {
      _controller.clear();
      _hasText = false;
      _focusNode.unfocus();
      if (_dictating) {
        _dictating = false;
        _voiceSub?.cancel();
        _voiceSub = null;
        NanoRuntimeApi.instance.stopSpeech();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _controller.removeListener(_onText);
    _voiceSub?.cancel();
    _internalController.dispose();
    _internalFocusNode.dispose();
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
      if ((config?.clearOnSubmit ?? true) && !(config?.isGenerating ?? false)) {
        _controller.clear();
        setState(() => _hasText = false);
      }
      if (!(config?.keepFocusOnSubmit ?? false)) {
        _focusNode.unfocus();
      }
    }
  }

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
        final mediaSize = MediaQuery.sizeOf(context);
        final isCompactLandscape =
            mediaSize.width > mediaSize.height && mediaSize.height < 520;
        final width = constraints.maxWidth;
        final narrow = width < 480 || widget.compact || isCompactLandscape;
        final radius = narrow ? 28.0 : 32.0;
        final vertTop = isCompactLandscape ? 5.0 : (narrow ? 8.0 : 10.0);
        final vertBottom = isCompactLandscape ? 4.0 : (narrow ? 6.0 : 8.0);
        final gap = isCompactLandscape ? 3.0 : (narrow ? 5.0 : 7.0);

        return Semantics(
          container: true,
          label: 'Barra cósmica multifunción Nano AI',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.40)
                      : const Color(0xFF0F172A).withValues(alpha: 0.12),
                  blurRadius: _focused ? 28 : 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: NanoNavTokens.accentAmber.withValues(
                    alpha: isDark ? 0.20 : 0.08,
                  ),
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 24,
                  sigmaY: 24,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: widget.transparent
                        ? (isDark
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x75102040),
                                  Color(0x85081226),
                                ],
                              )
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xC8FFFFFF),
                                  Color(0xA5F0F5FF),
                                ],
                              ))
                        : (isDark
                            ? NanoNavTokens.shellGradientDark
                            : NanoNavTokens.shellGradientLight),
                    border: Border.all(
                      color: _focused
                          ? NanoNavTokens.accentAmber.withValues(alpha: 0.92)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.65)),
                      width: _focused ? 1.3 : 1.0,
                    ),
                  ),
                  child: Stack(
                    children: [
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
                                Colors.white.withValues(
                                  alpha: isDark ? 0.35 : 0.8,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 10 : 12,
                          vertTop,
                          narrow ? 10 : 12,
                          vertBottom,
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
                              onAttach: config?.onAttach,
                              onSubmitted: _handleSearchSubmit,
                              onClear: () {
                                _controller.clear();
                                setState(() => _hasText = false);
                              },
                              onVoice:
                                  config?.onVoice ??
                                  widget.onVoice ??
                                  _toggleDefaultDictation,
                              listening:
                                  (config?.isListening ?? false) || _dictating,
                              compact: narrow,
                              transparent: widget.transparent,
                            ),
                            if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                              SizedBox(height: gap),
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
    required this.onAttach,
    required this.onSubmitted,
    required this.onClear,
    required this.onVoice,
    required this.listening,
    required this.compact,
    this.transparent = false,
  });

  final Brightness brightness;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool hasText;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onVoice;
  final bool listening;
  final bool compact;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final text = NanoNavTokens.text(brightness);
    final muted = NanoNavTokens.textMuted(brightness);

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: compact ? 38 : 44),
            decoration: BoxDecoration(
              color: dark
                  ? (focusNode.hasFocus
                      ? const Color(0x751E3A68)
                      : const Color(0x55162B4E))
                  : (focusNode.hasFocus
                      ? Colors.white
                      : const Color(0xF0FFFFFF)),
              borderRadius: BorderRadius.circular(compact ? 22 : 24),
              border: Border.all(
                color: focusNode.hasFocus
                    ? NanoNavTokens.accentAmber.withValues(alpha: 0.95)
                    : (dark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.09)),
                width: focusNode.hasFocus ? 1.3 : 1.0,
              ),
              boxShadow: focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: NanoNavTokens.accentAmber.withValues(alpha: 0.22),
                        blurRadius: 16,
                        spreadRadius: -1,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: dark ? 0.20 : 0.05,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: compact ? 10 : 13,
                    right: compact ? 6 : 8,
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: compact ? 19 : 21,
                    color: focusNode.hasFocus
                        ? NanoNavTokens.accentAmber
                        : (dark
                            ? const Color(0xFFA0B4D2)
                            : const Color(0xFF2C5282)),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: compact ? 3 : 5,
                    cursorColor: NanoNavTokens.accentAmber,
                    cursorWidth: 2.0,
                    cursorRadius: const Radius.circular(2),
                    style: TextStyle(
                      color: text,
                      fontSize: compact ? 13.2 : 14.2,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.05,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: compact ? 8 : 10,
                        horizontal: 4,
                      ),
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: muted.withValues(alpha: 0.75),
                        fontSize: compact ? 12.0 : 13.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (onAttach != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: IconButton(
                      icon: Icon(
                        Icons.attach_file_rounded,
                        size: compact ? 18 : 20,
                        color: muted,
                      ),
                      onPressed: onAttach,
                      tooltip: 'Adjuntar archivo',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: compact ? 30 : 34,
                        height: compact ? 30 : 34,
                      ),
                    ),
                  ),
                if (hasText)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Container(
                        width: compact ? 18 : 20,
                        height: compact ? 18 : 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: compact ? 12 : 13,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      onPressed: onClear,
                      tooltip: 'Limpiar texto',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: compact ? 26 : 30,
                        height: compact ? 26 : 30,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(right: compact ? 4 : 6),
                  child: hasText
                      ? Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onSubmitted?.call(controller.text);
                            },
                            child: Container(
                              width: compact ? 32 : 36,
                              height: compact ? 32 : 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF38BDF8),
                                    Color(0xFF2563EB),
                                    Color(0xFF1D4ED8),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.50),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                size: compact ? 17 : 19,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: compact ? 30 : 34,
                            height: compact ? 30 : 34,
                            alignment: Alignment.center,
                            decoration: listening
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.20),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.50),
                                      width: 1.2,
                                    ),
                                  )
                                : null,
                            child: Icon(
                              listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: compact ? 19 : 21,
                              color: listening
                                  ? const Color(0xFFEF4444)
                                  : (dark
                                      ? NanoNavTokens.accentAmber
                                      : const Color(0xFF2563EB)),
                            ),
                          ),
                          onPressed: onVoice,
                          tooltip: listening
                              ? 'Detener dictado'
                              : 'Dictar por voz',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: compact ? 32 : 36,
                            height: compact ? 32 : 36,
                          ),
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
              final indicatorWidth = compact ? 20.0 : 28.0;

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
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF38BDF8),
                          Color(0xFF2563EB),
                          Color(0xFF1D4ED8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.90),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.60),
                          blurRadius: 12,
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
    final dark = brightness == Brightness.dark;
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final active = NanoNavTokens.activeAccent(brightness);

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 2 : 4,
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
                  size: compact ? 17 : 22,
                  strokeWidth: selected ? 2.15 : 1.80,
                  glow: selected,
                ),
              ),
              SizedBox(height: compact ? 1 : 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  compact && destination == NanoDestination.automation
                      ? 'Auto'
                      : destination.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? active : muted,
                    fontSize: compact ? 7.8 : 9.8,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.05,
                    shadows: selected
                        ? [
                            Shadow(
                              color: active.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              SizedBox(height: compact ? 3 : 6),
            ],
          ),
        ),
      ),
    );
  }
}

