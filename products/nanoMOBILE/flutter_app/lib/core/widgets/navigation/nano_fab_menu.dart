// nano_fab_menu.dart — Menú vertical expandible del FAB de Nano AI estilo Liquid Glass.
//
// QUÉ HACE: Despliega una tarjeta vertical compacta con exactamente 3 destinos:
// 1. Mensajería (Centro de Mensajería oficial).
// 2. Tienda (Catálogo y tienda persistente de Nano Negocio).
// 3. Biblioteca (Almacén de documentos y archivos).
//
// CÓMO FUNCIONA:
// - Abre con animaciones suaves sincronizadas (ScaleTransition, FadeTransition, SlideTransition).
// - Al pulsar una opción, ejecuta la navegación real y cierra automáticamente el menú.
// - Reutiliza componentes y lógica existentes sin duplicar pantallas ni inventar rutas.
//
// POR QUÉ: Respeta principios SOLID, arquitectura reactiva y límite estricto < 180 líneas.
library;

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/automation/engine/business/business_facts_providers.dart';
import '../../../features/automation/presentation/business/business_document_library_dialog.dart';
import '../../../features/automation/presentation/business/business_library_section_tabs.dart';
import 'nano_fab_menu_item.dart';
import 'nano_nav_mode_provider.dart';

/// Menú expandible vertical anclado visualmente sobre el Nano FAB.
class NanoFabMenu extends ConsumerStatefulWidget {
  const NanoFabMenu({super.key, required this.brightness});
  final Brightness brightness;

  @override
  ConsumerState<NanoFabMenu> createState() => _NanoFabMenuState();
}

class _NanoFabMenuState extends ConsumerState<NanoFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(curve);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeMenu() {
    _controller.reverse().then((_) {
      if (mounted) ref.read(nanoNavModeProvider.notifier).closeFabMenu();
    });
  }

  void _openSection(BusinessLibrarySection section) {
    _closeMenu();
    HapticFeedback.selectionClick();
    ref.read(businessFactsNotifierProvider.notifier).ready.then((_) {
      if (!mounted) return;
      BusinessDocumentLibraryDialog.show(
        context,
        ref.read(businessFactsNotifierProvider),
        initialSection: section,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final bgColors = isDark
        ? [const Color(0xDE1C2333), const Color(0xC8121724)]
        : [const Color(0xF2FFFFFF), const Color(0xE2F1F5F9)];
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.85);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.bottomRight,
          child: Container(
            width: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: bgColors,
                    ),
                    border: Border.all(color: borderCol, width: 0.9),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NanoFabMenuItem(
                          icon: CupertinoIcons.chat_bubble_2_fill,
                          iconColor: const Color(0xFF007AFF),
                          label: 'Mensajería',
                          isDark: isDark,
                          onTap: () {
                            _closeMenu();
                            HapticFeedback.selectionClick();
                            context.push('/automation/messages');
                          },
                        ),
                        _divider(isDark),
                        NanoFabMenuItem(
                          icon: Icons.storefront_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          label: 'Tienda',
                          isDark: isDark,
                          onTap: () => _openSection(BusinessLibrarySection.store),
                        ),
                        _divider(isDark),
                        NanoFabMenuItem(
                          icon: CupertinoIcons.folder_fill,
                          iconColor: const Color(0xFF5856D6),
                          label: 'Biblioteca',
                          isDark: isDark,
                          onTap: () => _openSection(BusinessLibrarySection.documents),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Divider(
      height: 1,
      thickness: 0.6,
      color: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.06),
    ),
  );
}
