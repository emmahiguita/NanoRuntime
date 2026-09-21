import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/settings_provider.dart';
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
  ConsumerState<WhatsAppContactCard> createState() => _WhatsAppContactCardState();
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
    final contact = widget.contact;
    final initial = contact.name.trim().isNotEmpty ? contact.name.trim()[0].toUpperCase() : '?';
    final gradient = _gradients[contact.name.hashCode.abs() % _gradients.length];

    final targetMode = ref.watch(settingsProvider).waTargetContactsMode;
    final ownershipStore = ref.watch(conversationOwnershipStoreProvider);
    final keyId = contact.jid.isNotEmpty ? contact.jid : contact.number;
    final ownership = ownershipStore.ownershipFor(keyId) ??
        (contact.number.isNotEmpty ? ownershipStore.ownershipFor(contact.number) : null);

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
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0x551E293B), const Color(0x400F172A)]
                  : [const Color(0x381E293B), const Color(0x220F172A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBotActive
                  ? const Color(0xFF25D366).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: gradient[0],
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (contact.isBusiness)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A884).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF00A884).withValues(alpha: 0.5), width: 0.6),
                            ),
                            child: const Text('Business', style: TextStyle(color: Color(0xFF00A884), fontSize: 8.5, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.number.isNotEmpty ? contact.number : contact.jid,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
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
                  final newOwner = isBotActive ? ConversationOwner.human : ConversationOwner.bot;
                  if (contact.jid.isNotEmpty) {
                    await ownershipStore.setOwner(contact.jid, newOwner);
                  }
                  if (contact.number.isNotEmpty && contact.number != contact.jid) {
                    await ownershipStore.setOwner(contact.number, newOwner);
                  }
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isBotActive ? const Color(0xFF25D366).withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBotActive ? const Color(0xFF25D366).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBotActive ? Icons.smart_toy_rounded : Icons.pause_circle_outline_rounded,
                        size: 14,
                        color: isBotActive ? const Color(0xFF25D366) : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBotActive ? 'Activo' : 'Pausado',
                        style: TextStyle(
                          color: isBotActive ? const Color(0xFF25D366) : Colors.white60,
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
