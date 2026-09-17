import 'package:flutter/material.dart';
import '../../domain/whatsapp_contact.dart';

/// Tarjeta de contacto de WhatsApp para el Centro de Mensajería.
class WhatsAppContactCard extends StatefulWidget {
  final WhatsAppContact contact;
  final VoidCallback onTap;

  const WhatsAppContactCard({
    super.key,
    required this.contact,
    required this.onTap,
  });

  @override
  State<WhatsAppContactCard> createState() => _WhatsAppContactCardState();
}

class _WhatsAppContactCardState extends State<WhatsAppContactCard> {
  bool _pressed = false;

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF25D366), Color(0xFF128C7E)], // WA Verde
    [Color(0xFF00A884), Color(0xFF005C4B)], // WA Oscuro
    [Color(0xFF34B7F1), Color(0xFF0B648F)], // WA Azul
    [Color(0xFF10B981), Color(0xFF047857)], // Esmeralda
    [Color(0xFF06B6D4), Color(0xFF0E7490)], // Cian
  ];

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final initial = contact.name.trim().isNotEmpty
        ? contact.name.trim()[0].toUpperCase()
        : '?';

    final gradientIndex = contact.name.hashCode.abs() % _avatarGradients.length;
    final gradient = _avatarGradients[gradientIndex];

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                      const Color(0x551E293B),
                      const Color(0x400F172A),
                    ]
                  : [
                      const Color(0x381E293B),
                      const Color(0x220F172A),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _pressed
                  ? const Color(0xFF25D366).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.11),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Avatar con iniciales
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Información del contacto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge WhatsApp / WA Business
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: contact.isBusiness
                                ? const Color(0xFF00A884).withValues(alpha: 0.2)
                                : const Color(0xFF25D366).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: contact.isBusiness
                                  ? const Color(0xFF00A884).withValues(alpha: 0.6)
                                  : const Color(0xFF25D366).withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                contact.isBusiness
                                    ? Icons.business_center_rounded
                                    : Icons.chat_rounded,
                                size: 10,
                                color: contact.isBusiness
                                    ? const Color(0xFF00A884)
                                    : const Color(0xFF25D366),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                contact.isBusiness ? 'WA Business' : 'WhatsApp',
                                style: TextStyle(
                                  color: contact.isBusiness
                                      ? const Color(0xFF00A884)
                                      : const Color(0xFF25D366),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.number.isNotEmpty ? contact.number : contact.jid,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 3. Botón de acción / chat
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF25D366),
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
