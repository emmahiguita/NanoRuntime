// messaging_conversation_actions_sheet.dart
//
// QUÉ HACE:
// Menú contextual flotante con estética 100% iOS Frosted Glass para conversaciones del hub:
// cambio de agente (Personal/Negocios), archivar/desarchivar, limpiar memoria y quitar del centro.
//
// CÓMO FUNCIONA:
// - Despliega un menú flotante con BackdropFilter blur, esquinas redondeadas y borde translúcido reflectante.
// - Aplica respuestas hápticas y confirmaciones seguras mediante NanoGlassDialog.
// - Ejecuta acciones reales en ConversationHubActionController sin alterar datos remotos de WhatsApp.
//
// POR QUÉ:
// Reemplaza hojas modales opacas por una experiencia iOS Flotante Glass limpia y moderna (< 175 líneas).

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/conversation_agent.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../widgets/nano_glass_dialog.dart';
import '../widgets/nano_metallic_button.dart';
import 'conversation_hub_action_controller.dart';

enum _ConversationAction { archive, unarchive, clearMemory, remove, transferAgent }

Future<void> showMessagingConversationActions(
  BuildContext context, WidgetRef ref, ConversationSummaryItem item, {
  required bool isArchived, ConversationAgentId? currentAgent,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final target = currentAgent == ConversationAgentId.business ? ConversationAgentId.personal : ConversationAgentId.business;

  final action = await showModalBottomSheet<_ConversationAction>(
    context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85), width: 1.1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                _tile(icon: Icons.swap_horiz_rounded, color: const Color(0xFF38BDF8), title: 'Agente: ${currentAgent?.displayName ?? "Personal"}', subtitle: 'Cambiar a → ${target.displayName}', isDark: isDark, onTap: () => Navigator.pop(ctx, _ConversationAction.transferAgent)),
                _div(isDark),
                _tile(icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded, color: const Color(0xFF818CF8), title: isArchived ? 'Desarchivar en Nano' : 'Archivar en Nano', subtitle: 'Organiza la lista local; no cambia WhatsApp.', isDark: isDark, onTap: () => Navigator.pop(ctx, isArchived ? _ConversationAction.unarchive : _ConversationAction.archive)),
                _div(isDark),
                _tile(icon: Icons.cleaning_services_rounded, color: const Color(0xFFF59E0B), title: 'Limpiar memoria de Nano', subtitle: 'Borra el contexto aprendido de este chat.', isDark: isDark, onTap: () => Navigator.pop(ctx, _ConversationAction.clearMemory)),
                _div(isDark),
                _tile(icon: Icons.delete_outline_rounded, color: const Color(0xFFEF4444), title: 'Quitar del centro de Nano', subtitle: 'Borra memoria local y quita la notificación.', isDark: isDark, isDanger: true, onTap: () => Navigator.pop(ctx, _ConversationAction.remove)),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (action == null || !context.mounted) return;
  if (action == _ConversationAction.clearMemory || action == _ConversationAction.remove) {
    final confirmed = await _confirmDestructive(context, action, isDark);
    if (!confirmed || !context.mounted) return;
  }

  final ctrl = ref.read(conversationHubActionControllerProvider);
  try {
    final msg = switch (action) {
      _ConversationAction.archive => ctrl.setArchived(item, archived: true).then((_) => 'Conversación archivada en Nano.'),
      _ConversationAction.unarchive => ctrl.setArchived(item, archived: false).then((_) => 'Conversación desarchivada.'),
      _ConversationAction.clearMemory => ctrl.clearNanoMemory(item).then((_) => 'Memoria local eliminada.'),
      _ConversationAction.remove => ctrl.removeFromNano(item).then((_) => 'Conversación quitada de Nano.'),
      _ConversationAction.transferAgent => ctrl.transferAgent(item, target).then((_) => 'Agente cambiado a ${target.displayName}.'),
    };
    final text = await msg;
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), behavior: SnackBarBehavior.floating));
  }
}

Widget _tile({required IconData icon, required Color color, required String title, required String subtitle, required bool isDark, required VoidCallback onTap, bool isDanger = false}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isDanger ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _div(bool isDark) => Divider(height: 1, indent: 64, color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05));

Future<bool> _confirmDestructive(BuildContext context, _ConversationAction action, bool isDark) async {
  final isRemove = action == _ConversationAction.remove;
  return await NanoGlassDialog.show<bool>(
        context: context,
        title: isRemove ? '¿Quitar de Nano?' : '¿Limpiar memoria?',
        content: Text(
          isRemove ? 'Se borrará el contexto local y la notificación. El chat seguirá en WhatsApp.' : 'Se borrará el contexto aprendido. Los mensajes seguirán en WhatsApp.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF475569), height: 1.4),
        ),
        icon: isRemove ? Icons.delete_sweep_rounded : Icons.cleaning_services_rounded,
        iconColor: const Color(0xFFEF4444),
        actions: [
          NanoMetallicButton(label: 'Cancelar', style: NanoMetallicButtonStyle.subtle, onPressed: () => Navigator.pop(context, false)),
          NanoMetallicButton(label: isRemove ? 'Quitar' : 'Limpiar', style: NanoMetallicButtonStyle.danger, onPressed: () => Navigator.pop(context, true)),
        ],
      ) ?? false;
}
