import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nano_destination.dart';
import 'nano_glyph.dart';
import 'nano_nav_tokens.dart';

/// Barra de navegación multifunción cósmica de Nano AI.
///
/// Implementa la arquitectura de dos niveles:
/// 1. Nivel superior: Avatar con aro orbital y estado online + Barra de
///    búsqueda/prompt con botones dedicados para micrófono y envío.
/// 2. Nivel inferior: Dock de 6 destinos con indicador de punto brillante
///    neón y efectos de resplandor activo.
class NanoMultiUseNavBar extends StatefulWidget {
  const NanoMultiUseNavBar({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    this.onSearch,
    this.onVoice,
    this.onAvatarTap,
    this.searchHint = 'Describe qué quieres automatizar...',
    this.brightness,
    this.compact = false,
    this.showFeather = true,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchSubmit([String? value]) {
    final query = value ?? _controller.text;
    if (query.trim().isNotEmpty) {
      HapticFeedback.mediumImpact();
      widget.onSearch?.call(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness ?? Theme.of(context).brightness;
    final isDark = b == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final narrow = width < 480 || widget.compact;
        final radius = narrow ? 26.0 : 30.0;

        return Semantics(
          container: true,
          label: 'Barra multifunción Nano AI',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: NanoNavTokens.shell(b),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: _focused
                        ? NanoNavTokens.electricBlue.withValues(alpha: .78)
                        : NanoNavTokens.stroke(b),
                    width: _focused ? 1.25 : .85,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NanoNavTokens.accentBlue.withValues(
                        alpha: isDark ? .28 : .12,
                      ),
                      blurRadius: _focused ? 34 : 24,
                      spreadRadius: _focused ? 1 : -2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? .38 : .08,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (widget.showFeather)
                      Positioned(
                        right: -10,
                        bottom: -28,
                        width: narrow ? 140 : 190,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: isDark ? .65 : .28,
                            child: Image.asset(
                              'assets/nano/nano_feather.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 9 : 12,
                        narrow ? 9 : 11,
                        narrow ? 9 : 12,
                        narrow ? 7 : 9,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SearchRow(
                            brightness: b,
                            controller: _controller,
                            focusNode: _focusNode,
                            hint: widget.searchHint,
                            onSubmitted: _handleSearchSubmit,
                            onVoice: widget.onVoice,
                            onAvatarTap: widget.onAvatarTap,
                            compact: narrow,
                          ),
                          SizedBox(height: narrow ? 6 : 8),
                          _DestinationDock(
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
    required this.onSubmitted,
    required this.onVoice,
    required this.onAvatarTap,
    required this.compact,
  });

  final Brightness brightness;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onVoice;
  final VoidCallback? onAvatarTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final text = NanoNavTokens.text(brightness);
    final muted = NanoNavTokens.textMuted(brightness);

    return Row(
      children: [
        _AvatarButton(
          brightness: brightness,
          size: compact ? 44 : 50,
          onTap: onAvatarTap,
        ),
        SizedBox(width: compact ? 7 : 9),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: dark ? const Color(0x75102048) : const Color(0xCCFFFFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: focusNode.hasFocus
                    ? NanoNavTokens.electricBlue.withValues(alpha: .92)
                    : NanoNavTokens.stroke(brightness).withValues(alpha: .72),
                width: focusNode.hasFocus ? 1.1 : 0.8,
              ),
              boxShadow: focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: NanoNavTokens.accentBlue.withValues(alpha: .34),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(width: compact ? 9 : 12),
                NanoGlyph(
                  type: NanoGlyphType.search,
                  color: focusNode.hasFocus
                      ? NanoNavTokens.electricBlue
                      : muted,
                  size: compact ? 18 : 20,
                  strokeWidth: 1.9,
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: text,
                      fontSize: compact ? 12.5 : 13.5,
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
                        fontSize: compact ? 11.5 : 12.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 18,
                  width: 0.7,
                  color: NanoNavTokens.separator(brightness),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                _CircularActionButton(
                  tooltip: 'Voz',
                  gradient: const RadialGradient(
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
                  shadowColor: NanoNavTokens.cyan.withValues(alpha: .40),
                  glyph: NanoGlyphType.microphone,
                  size: compact ? 32 : 36,
                  iconSize: compact ? 16 : 18,
                  onTap: onVoice,
                ),
                const SizedBox(width: 4),
                _CircularActionButton(
                  tooltip: 'Enviar',
                  gradient: NanoNavTokens.sendButtonGradient,
                  shadowColor: NanoNavTokens.accentBlue.withValues(alpha: .50),
                  glyph: NanoGlyphType.arrowForward,
                  size: compact ? 32 : 36,
                  iconSize: compact ? 17 : 19,
                  onTap: () => onSubmitted?.call(controller.text),
                ),
                SizedBox(width: compact ? 4 : 5),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  const _CircularActionButton({
    required this.tooltip,
    required this.gradient,
    required this.shadowColor,
    required this.glyph,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  final String tooltip;
  final Gradient gradient;
  final Color shadowColor;
  final NanoGlyphType glyph;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              border: Border.all(
                color: Colors.white.withValues(alpha: .55),
                width: .85,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Center(
              child: NanoGlyph(
                type: glyph,
                color: Colors.white,
                size: iconSize,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
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
              padding: const EdgeInsets.all(2.2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: NanoNavTokens.activeGradient,
                boxShadow: [
                  BoxShadow(
                    color: NanoNavTokens.accentBlue.withValues(alpha: .45),
                    blurRadius: 14,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(1.8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: brightness == Brightness.dark
                      ? const Color(0xFF071224)
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
                width: size * .22,
                height: size * .22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NanoNavTokens.neonGreen,
                  border: Border.all(
                    color: brightness == Brightness.dark
                        ? const Color(0xFF030B20)
                        : Colors.white,
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NanoNavTokens.neonGreen.withValues(alpha: .9),
                      blurRadius: 6,
                      spreadRadius: .5,
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

class _DestinationDock extends StatelessWidget {
  const _DestinationDock({
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
    final dark = brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 3 : 6,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark
            ? const Color(0x350A1A3B)
            : const Color(0x203B82F6),
        border: Border.all(
          color: dark
              ? const Color(0x334B7FFF)
              : const Color(0x263B82F6),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          for (final d in NanoDestination.values)
            Expanded(
              child: _DestinationButton(
                destination: d,
                selected: selected == d,
                brightness: brightness,
                compact: compact,
                onTap: () => onSelected(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
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
        ? const Color(0xFF5CE7FF)
        : const Color(0xFF0284C7);

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                duration: const Duration(milliseconds: 220),
                scale: selected ? 1.08 : 1.0,
                child: NanoGlyph(
                  type: destination.glyph,
                  color: selected ? active : muted,
                  size: compact ? 19 : 21,
                  strokeWidth: selected ? 2.1 : 1.7,
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
                    fontSize: compact ? 8.6 : 9.5,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -.05,
                    shadows: selected
                        ? [
                            Shadow(
                              color: active.withValues(alpha: .5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 5.5 : 0.0,
                height: selected ? 5.5 : 0.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: active.withValues(alpha: .9),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
