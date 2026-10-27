import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/whatsapp_contact.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../../application/automation_coordinator_provider.dart';

/// WHATSAPP-CONTACT-CARD — Tarjeta de contacto con control de agente Nano (< 190 líneas).
///
/// **QUÉ HACE:**
/// Muestra datos de contacto y un toggle para activar o pausar el agente Nano.
///
/// **CÓMO FUNCIONA:**
/// Consulta [conversationOwnershipStoreProvider]. Al pulsar, persiste el estado
/// [ConversationOwner.bot] o [ConversationOwner.human].
///
/// **POR QUÉ:**
/// Otorga control directo y transparente sobre qué contactos son atendidos por la IA.
class WhatsAppContactCard extends ConsumerStatefulWidget {
  final WhatsAppContact contact;
  final VoidCallback onTap;

  const WhatsAppContactCard({
    super.key,
    required this.contact,
    required this.onTap,
  });

  @override
  ConsumerState<WhatsAppContactCard> createState() =>
      _WhatsAppContactCardState();
}

class _WhatsAppContactCardState extends ConsumerState<WhatsAppContactCard> {
  bool _pressed = false;

  static const _gradients = [
    [Color(0xFF1D6FE8), Color(0xFF1E40AF)],
    [Color(0xFF0284C7), Color(0xFF0369A1)],
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    [Color(0xFF6366F1), Color(0xFF4338CA)],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final contact = widget.contact;
    final initial = contact.name.trim().isNotEmpty
        ? contact.name.trim()[0].toUpperCase()
        : '?';
    final gradient =
        _gradients[contact.name.hashCode.abs() % _gradients.length];

    final targetMode = ref.watch(settingsProvider).waTargetContactsMode;
    final ownershipStore = ref.watch(conversationOwnershipStoreProvider);
    final keyId = contact.jid.isNotEmpty ? contact.jid : contact.number;
    final ownership =
        ownershipStore.ownershipFor(keyId) ??
        (contact.number.isNotEmpty
            ? ownershipStore.ownershipFor(contact.number)
            : null) ??
        (contact.name.isNotEmpty
            ? ownershipStore.ownershipFor(contact.name)
            : null);

    final bool isBotActive = targetMode == 'selected'
        ? ownership?.owner == ConversationOwner.bot
        : !(ownership?.humanOwns ?? false);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isDark
                ? (_pressed ? const Color(0x551E293B) : const Color(0x381E293B))
                : (_pressed ? const Color(0xFFF1F5F9) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : const Color(0xFFE2E8F0),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: gradient[0],
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : colors.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.number.isNotEmpty ? contact.number : contact.jid,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : colors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStateButton(isBotActive, isDark, colors, ownershipStore),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateButton(
    bool isBotActive,
    bool isDark,
    dynamic colors,
    dynamic ownershipStore,
  ) {
    final contact = widget.contact;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final newOwner = isBotActive
            ? ConversationOwner.human
            : ConversationOwner.bot;
        if (contact.jid.isNotEmpty) {
          await ownershipStore.setOwner(contact.jid, newOwner);
        }
        if (contact.number.isNotEmpty && contact.number != contact.jid) {
          await ownershipStore.setOwner(contact.number, newOwner);
        }
        if (contact.name.isNotEmpty) {
          await ownershipStore.setOwner(contact.name, newOwner);
        }
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isBotActive
              ? (isDark
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                  : const Color(0xFFE0F2FE))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isBotActive
                ? const Color(0xFF38BDF8)
                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBotActive
                  ? Icons.smart_toy_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 13,
              color: isBotActive
                  ? const Color(0xFF38BDF8)
                  : (isDark ? Colors.white54 : colors.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Text(
              isBotActive ? 'Activo' : 'Pausado',
              style: TextStyle(
                color: isBotActive
                    ? (isDark ? Colors.white : const Color(0xFF0369A1))
                    : (isDark ? Colors.white60 : colors.onSurfaceVariant),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
