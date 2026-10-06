import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/whatsapp_contact.dart';
import '../../personal_agent/domain/conversation_owner.dart';
import '../../application/automation_coordinator_provider.dart';

/// WHATSAPP-CONTACT-CARD — Tarjeta de contacto con control de agente Nano.
///
/// **QUÉ HACE:**
/// Muestra datos de contacto de WhatsApp y un switch/toggle para activar
/// o pausar el agente Nano individualmente para ese contacto.
///
/// **CÓMO FUNCIONA:**
/// Consulta [conversationOwnershipStoreProvider] y [settingsProvider]. Al conmutar,
/// persiste de forma durable el nuevo [ConversationOwner] en SQLite.
///
/// **POR QUÉ:**
/// Permite al usuario decidir exactamente en qué conversaciones opera el bot.
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
    [Color(0xFF25D366), Color(0xFF128C7E)],
    [Color(0xFF00A884), Color(0xFF005C4B)],
    [Color(0xFF34B7F1), Color(0xFF0B648F)],
    [Color(0xFF10B981), Color(0xFF047857)],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final botColor = isDark ? const Color(0xFF25D366) : colors.primary;

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
            : null);

    // Solo cuentas confirmadas pueden recibir automatización; teléfonos comunes quedan manuales.
    final bool isBotActive = contact.isWhatsAppVerified &&
        (targetMode == 'selected'
            ? ownership?.owner == ConversationOwner.bot
            : !(ownership?.humanOwns ?? false));

    final border = isBotActive
        ? botColor.withValues(alpha: isDark ? 0.35 : 0.45)
        : (isDark ? Colors.white.withValues(alpha: 0.1) : colors.outline);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? null : (_pressed ? const Color(0xFFF1F5F9) : Colors.white),
            gradient: isDark
                ? LinearGradient(
                    colors: _pressed
                        ? [const Color(0x551E293B), const Color(0x400F172A)]
                        : [const Color(0x381E293B), const Color(0x220F172A)],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : colors.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (contact.isBusiness)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF00A884).withValues(alpha: 0.2)
                                  : const Color(0xFF0F766E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF00A884).withValues(alpha: 0.5)
                                    : const Color(0xFF0F766E).withValues(alpha: 0.4),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'Business',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF00A884)
                                    : const Color(0xFF0F766E),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.isWhatsAppVerified
                          ? (contact.number.isNotEmpty ? contact.number : contact.jid)
                          : '${contact.number} · No verificado',
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
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  if (!contact.isWhatsAppVerified) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Este número no está confirmado como cuenta de WhatsApp.')),
                    );
                    return;
                  }
                  final newOwner = isBotActive
                      ? ConversationOwner.human
                      : ConversationOwner.bot;
                  if (contact.jid.isNotEmpty) {
                    await ownershipStore.setOwner(contact.jid, newOwner);
                  }
                  if (contact.number.isNotEmpty &&
                      contact.number != contact.jid) {
                    await ownershipStore.setOwner(contact.number, newOwner);
                  }
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isBotActive
                        ? botColor.withValues(alpha: isDark ? 0.16 : 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBotActive
                          ? botColor.withValues(alpha: isDark ? 0.45 : 0.50)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : colors.outline),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBotActive
                            ? Icons.smart_toy_rounded
                            : contact.isWhatsAppVerified
                                ? Icons.pause_circle_outline_rounded
                                : Icons.help_outline_rounded,
                        size: 14,
                        color: isBotActive
                            ? botColor
                            : (isDark ? Colors.white54 : colors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBotActive
                            ? 'Activo'
                            : contact.isWhatsAppVerified
                                ? 'Pausado'
                                : 'No verificado',
                        style: TextStyle(
                          color: isBotActive
                              ? botColor
                              : (isDark ? Colors.white60 : colors.onSurfaceVariant),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
