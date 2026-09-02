import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'noar_builtin_commands.dart';

/// Noar Command Library — sábana flotante estilo iOS (TER-15).
///
/// Glassmorphism real: BackdropFilter con blur sobre el terminal que queda
/// detrás (el modal es transparente), gradiente translúcido, borde blanco
/// fino y sombra profunda. Entrada animada (slide + fade + overshoot) al
/// montarse, chips de tags con transición animada, tarjetas de comando con
/// presión táctil (escala) y botón de ejecutar prominente.
class NoarPanel extends StatefulWidget {
  final List<Map<String, dynamic>> library;
  final Color fg;
  final bool dark;

  /// Ejecuta el comando en el terminal activo (bash PTY real o dispatcher).
  /// El panel se cierra tras usarlo.
  final void Function(String cmd)? onUse;

  const NoarPanel({
    super.key,
    required this.library,
    required this.fg,
    required this.dark,
    this.onUse,
  });

  @override
  State<NoarPanel> createState() => _NoarPanelState();
}

class _NoarPanelState extends State<NoarPanel> {
  String _search = '';
  String _activeTag = 'all';
  bool _entered = false;
  final _searchCtl = TextEditingController();

  // TER-15: acento cian de la paleta pizarra/cian (TER-13/14) — mismo
  // lenguaje visual que el FAB y la barra de modificadores.
  static const Color _accent = Color(0xFF38BDF8);
  static const Color _steel = Color(0xFF9FB3C8);
  static const Color _ink = Color(0xFFE2E8F0);

  static const _tags = {
    'all': 'Todo',
    'fs': 'FS',
    'shell': 'Shell',
    'rootfs': 'Rootfs',
    'pkgs': 'Pkgs',
    'kali': 'Kali',
    'containers': 'Docker',
    'monitor': 'Monitor',
    'remote': 'Remote',
    'ai': 'IA',
    'general': 'General',
  };

  List<Map<String, dynamic>> get _filtered {
    final all = [...noarBuiltinCommands, ...widget.library];
    return all.where((c) {
      final tag = c['tag'] as String? ?? 'general';
      if (_activeTag != 'all' && tag != _activeTag) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final cmd = (c['cmd'] as String? ?? '').toLowerCase();
        final desc = (c['desc'] as String? ?? '').toLowerCase();
        if (!cmd.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copiado: $text',
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: widget.fg.withValues(alpha: 0.15),
      ),
    );
  }

  void _use(String cmd) {
    if (widget.onUse == null) {
      _copy(cmd); // sin callback: copiar sigue siendo útil
      return;
    }
    widget.onUse!(cmd);
    Navigator.pop(context); // cerrar el panel tras usar
  }

  @override
  void initState() {
    super.initState();
    // TER-15: entrada iOS — el contenido arranca desplazado/atenuado y
    // entra con overshoot en el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    // Tono neutro sobre el que se aplican los alphas: blanco en dark,
    // negro en light.
    final neutral = dark ? Colors.white : Colors.black;
    final items = _filtered;
    final surface = dark ? const Color(0xFF07192B) : const Color(0xFFEDEFF7);

    return Padding(
      // TER-15: flotante — separado de los bordes de la pantalla como
      // sheet iOS (no pegado a ras como modal plano).
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: AnimatedSlide(
        offset: _entered ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          opacity: _entered ? 1.0 : 0.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? [
                            Colors.white.withValues(alpha: 0.10),
                            const Color(0xFF0B1C33).withValues(alpha: 0.82),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.55),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: neutral.withValues(alpha: 0.16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ── Handle bar iOS ──
                    Container(
                      margin: const EdgeInsets.only(top: 9),
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: neutral.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _accent.withValues(alpha: 0.22),
                                  _accent.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: _accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Noar Library',
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: dark ? _ink : const Color(
                                        0xFF1A2438),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'comandos verificados del rootfs',
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 10.5,
                                    letterSpacing: 0.3,
                                    color: dark
                                        ? _steel.withValues(alpha: 0.85)
                                        : const Color(0xFF46536B)
                                            .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${items.length}',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Search ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      child: TextField(
                        controller: _searchCtl,
                        onChanged: (v) => setState(() => _search = v),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                          color: dark ? _ink : const Color(0xFF1A2438),
                        ),
                        cursorColor: _accent,
                        decoration: InputDecoration(
                          hintText: 'buscar comando o descripción…',
                          hintStyle: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: neutral.withValues(alpha: 0.3),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _accent.withValues(alpha: 0.7),
                            size: 19,
                          ),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 17,
                                    color: neutral.withValues(alpha: 0.45),
                                  ),
                                  onPressed: () {
                                    _searchCtl.clear();
                                    setState(() => _search = '');
                                  },
                                ),
                          filled: true,
                          fillColor: neutral.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: neutral.withValues(alpha: 0.09),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: neutral.withValues(alpha: 0.09),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _accent.withValues(alpha: 0.45),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),

                    // ── Tags chips ──
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        children: _tags.entries.map((e) {
                          final active = _activeTag == e.key;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _activeTag = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? _accent.withValues(alpha: 0.18)
                                      : neutral.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: active
                                        ? _accent.withValues(alpha: 0.5)
                                        : neutral.withValues(alpha: 0.07),
                                  ),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: _accent.withValues(
                                                alpha: 0.15),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    letterSpacing: 0.3,
                                    color: active
                                        ? _accent
                                        : dark
                                            ? _steel.withValues(alpha: 0.75)
                                            : const Color(0xFF46536B)
                                                .withValues(alpha: 0.75),
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ── Command list ──
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                'sin resultados',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  color: neutral.withValues(alpha: 0.3),
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final cmd = items[i];
                                return _CommandCard(
                                  cmd: cmd,
                                  tagLabel: _tags[cmd['tag']] ??
                                      (cmd['tag'] as String? ?? 'general'),
                                  isHistory: cmd.containsKey('ts'),
                                  fg: widget.fg,
                                  dark: dark,
                                  surface: surface,
                                  onCopy: () => _copy(
                                    cmd['cmd'] as String? ?? '',
                                  ),
                                  onUse: () => _use(cmd['cmd'] as String? ?? ''),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de comando con presión táctil (escala 0.97) y botón de ejecutar
/// prominente (círculo acento cian). TER-15.
class _CommandCard extends StatefulWidget {
  const _CommandCard({
    required this.cmd,
    required this.tagLabel,
    required this.isHistory,
    required this.fg,
    required this.dark,
    required this.surface,
    required this.onCopy,
    required this.onUse,
  });

  final Map<String, dynamic> cmd;
  final String tagLabel;
  final bool isHistory;
  final Color fg;
  final bool dark;
  final Color surface;
  final VoidCallback onCopy;
  final VoidCallback onUse;

  @override
  State<_CommandCard> createState() => _CommandCardState();
}

class _CommandCardState extends State<_CommandCard> {
  static const Color _accent = Color(0xFF38BDF8);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cmd = widget.cmd['cmd'] as String? ?? '';
    final desc = widget.cmd['desc'] as String? ?? '';
    final dark = widget.dark;
    final neutral = dark ? Colors.white : Colors.black;
    final steel = dark
        ? const Color(0xFF9FB3C8)
        : const Color(0xFF46536B);
    final codeBg = dark ? const Color(0xFF06101E) : const Color(0xFF101D33);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.015),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.55),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: neutral.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.22 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag + historial + acciones
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      widget.tagLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _accent,
                      ),
                    ),
                  ),
                  if (widget.isHistory) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.history_rounded,
                      size: 12,
                      color: neutral.withValues(alpha: 0.3),
                    ),
                  ],
                  const Spacer(),
                  // Ejecutar: botón prominente.
                  GestureDetector(
                    onTap: widget.onUse,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _accent.withValues(alpha: 0.9),
                            _accent.withValues(alpha: 0.65),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 19,
                        color: Color(0xFF04202E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onCopy,
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: neutral.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Comando — bloque oscuro monoespaciado, prompt incluido.
              GestureDetector(
                onTap: widget.onCopy,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: codeBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: neutral.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Text(
                    cmd,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.5,
                      color: widget.fg,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      color: steel.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
