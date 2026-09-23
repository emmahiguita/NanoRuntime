import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_credential_notifier.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_add_credential_dialog.dart';
import 'package:nanoai/features/browser/presentation/widgets/browser_credential_tile.dart';

/// Hoja modal estilo Liquid Glass para administrar contraseñas guardadas en el navegador.
///
/// Principios SOLID y Clean Architecture:
/// - SRP: Coordinador principal de la vista de bóveda, delegando edición a [BrowserAddCredentialDialog]
///   y renderizado de elementos a [BrowserCredentialTile].
/// - Líneas concisas (<200) y arquitectura completamente desacoplada.
class BrowserCredentialsSheet extends ConsumerStatefulWidget {
  final String? currentDomain;
  final void Function(String username, String password)? onAutofill;

  const BrowserCredentialsSheet({super.key, this.currentDomain, this.onAutofill});

  static Future<void> show({
    required BuildContext context,
    String? currentDomain,
    void Function(String username, String password)? onAutofill,
  }) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => BrowserCredentialsSheet(currentDomain: currentDomain, onAutofill: onAutofill),
    );
  }

  @override
  ConsumerState<BrowserCredentialsSheet> createState() => _BrowserCredentialsSheetState();
}

class _BrowserCredentialsSheetState extends ConsumerState<BrowserCredentialsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _revealedIds = {};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final credentials = ref.watch(browserCredentialProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    final filtered = credentials.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.domain.toLowerCase().contains(q) || c.username.toLowerCase().contains(q);
    }).toList();

    return Center(
      child: Container(
        width: mq.size.width - 24,
        constraints: BoxConstraints(maxWidth: isLandscape ? 560 : 440, maxHeight: mq.size.height * (isLandscape ? 0.96 : 0.88)),
        margin: EdgeInsets.only(bottom: isLandscape ? 6 : 24, top: isLandscape ? 4 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: isDark
              ? const [Color(0x6638BDF8), Color(0x33818CF8), Color(0x1A0F172A), Color(0x442DD4BF)]
              : const [Color(0xCCFFFFFF), Color(0x66FFFFFF), Color(0x33FFFFFF), Color(0x99FFFFFF)]),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 36, spreadRadius: -4, offset: const Offset(0, 16))],
        ),
        padding: const EdgeInsets.all(1.2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xF20B1322) : const Color(0xF2FFFFFF),
                borderRadius: BorderRadius.circular(28.8),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.65), width: 0.7),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Píldora de agarre iOS
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cabecera con título y acciones rápidas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.0),
                          ),
                          child: const Icon(Icons.vpn_key_rounded, size: 17, color: Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bóveda de Credenciales', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Almacenamiento seguro cifrado HMAC-SHA256', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8), size: 22), onPressed: () => BrowserAddCredentialDialog.show(context, initialDomain: widget.currentDomain)),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Buscador en vivo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(hintText: 'Buscar por sitio o usuario...', hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11.5), border: InputBorder.none, isDense: true),
                              onChanged: (val) => setState(() => _query = val.trim()),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 15), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF1E293B), height: 1),
                  // Lista de credenciales usando BrowserCredentialTile
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No hay contraseñas guardadas en la bóveda cifrada', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))))
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final cred = filtered[index];
                              final isCurrent = widget.currentDomain != null &&
                                  (cred.domain.contains(widget.currentDomain!) || widget.currentDomain!.contains(cred.domain));
                              return BrowserCredentialTile(
                                credential: cred,
                                isRevealed: _revealedIds.contains(cred.id),
                                isCurrentSite: isCurrent,
                                onToggleReveal: () => setState(() => _revealedIds.contains(cred.id) ? _revealedIds.remove(cred.id) : _revealedIds.add(cred.id)),
                                onAutofill: (user, pass) {
                                  widget.onAutofill?.call(user, pass);
                                  ref.read(browserCredentialProvider.notifier).updateLastUsed(cred.id);
                                  Navigator.pop(context);
                                },
                                onDelete: () => ref.read(browserCredentialProvider.notifier).deleteCredential(cred.id),
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
    );
  }
}
