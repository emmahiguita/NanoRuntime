// QUÉ: Hoja modal iOS frosted glass para alternar entre pantallas de Nano AI.
// CÓMO: Presenta accesos directos táctiles a Dashboard, Chat, Modelos, Terminal, Mensajería y Ajustes.
// POR QUÉ: Permite navegar entre módulos desde el navegador sin depender del botón atrás del sistema.

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class _ScreenItem {
  final String title, subtitle, route;
  final IconData icon;
  final List<Color> colors;

  const _ScreenItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.colors,
  });
}

class BrowserScreensHubSheet extends StatelessWidget {
  const BrowserScreensHubSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BrowserScreensHubSheet(),
    );
  }

  static const _screens = [
    _ScreenItem(
      title: 'Inicio',
      subtitle: 'Panel principal',
      route: '/dashboard',
      icon: CupertinoIcons.house_fill,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    _ScreenItem(
      title: 'Chat IA',
      subtitle: 'Asistente y agentes',
      route: '/chat',
      icon: CupertinoIcons.chat_bubble_2_fill,
      colors: [Color(0xFF10B981), Color(0xFF047857)],
    ),
    _ScreenItem(
      title: 'Modelos',
      subtitle: 'LLMs en dispositivo',
      route: '/models',
      icon: CupertinoIcons.sparkles,
      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ),
    _ScreenItem(
      title: 'Terminal',
      subtitle: 'Consola y Kali Linux',
      route: '/terminal',
      icon: CupertinoIcons.chevron_left_slash_chevron_right,
      colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
    ),
    _ScreenItem(
      title: 'Mensajes',
      subtitle: 'WhatsApp y mensajería',
      route: '/automation/messages',
      icon: CupertinoIcons.bubble_left_bubble_right_fill,
      colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
    ),
    _ScreenItem(
      title: 'Ajustes',
      subtitle: 'Configuración general',
      route: '/settings',
      icon: CupertinoIcons.gear_alt_fill,
      colors: [Color(0xFF64748B), Color(0xFF334155)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xE610141E) : const Color(0xF2F8FAFC);
    final border = isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: border, width: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Módulos de Nano AI',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: isDark ? Colors.white54 : Colors.black38),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: _screens.map((s) => _tile(context, s, isDark, border)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, _ScreenItem s, bool isDark, Color border) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          context.go(s.route);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 0.6),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: s.colors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
