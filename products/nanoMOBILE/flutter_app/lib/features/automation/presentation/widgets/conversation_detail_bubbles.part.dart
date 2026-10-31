part of 'conversation_detail_sheet.dart';

/// [ConversationDetailBubbles] — Burbujas estilo Liquid Glass conectadas al tema real del sistema (< 160 líneas).
// QUÉ HACE: Renderiza mensajes entrantes y salientes adaptando colores cromáticos a los tokens reales de Nano AI.
// CÓMO FUNCIONA: Usa visual.accent y visual.resolvedColors para componer gradientes y transparencias reactivas al tema.
// POR QUÉ: Asegura que el chat se transforme coherentemente con cualquier tema elegido por el usuario (Oscuro, Claro, Grisáceo).
extension ConversationDetailBubbles on _ConversationDetailSheetState {
  Color _getSenderColor(String sender) {
    const colors = [
      Color(0xFF38BDF8),
      Color(0xFF34D399),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
      Color(0xFF2DD4BF),
    ];
    return colors[sender.hashCode.abs() % colors.length];
  }

  Widget _buildChatBubble(
    String text,
    bool isInbound,
    AutomationVisualPalette visual, {
    String? sender,
    int? timestampMs,
  }) {
    final colors = visual.resolvedColors;
    final themeExt = NanoThemeExtension.of(context);
    final blurSigma = themeExt.glassEnabled
        ? (themeExt.glassBlur * 0.7).clamp(8.0, 18.0)
        : 0.0;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isInbound ? 3 : 18),
      bottomRight: Radius.circular(isInbound ? 18 : 3),
    );

    final outboundTop = visual.accent;
    final outboundBottom = colors.primary;

    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * (isLandscape ? 0.62 : 0.78),
        ),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isInbound
                  ? visual.shadow.withValues(
                      alpha: visual.isDark ? 0.20 : 0.04,
                    )
                  : visual.accent.withValues(
                      alpha: visual.isDark ? 0.25 : 0.18,
                    ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 8.5,
              ),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: isInbound
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: visual.isDark
                            ? [
                                colors.surfaceVariant.withValues(alpha: 0.45),
                                colors.surface.withValues(alpha: 0.60),
                              ]
                            : [
                                colors.surface.withValues(alpha: 0.90),
                                colors.surfaceVariant.withValues(alpha: 0.80),
                              ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          outboundTop.withValues(alpha: 0.82),
                          outboundBottom.withValues(alpha: 0.92),
                        ],
                      ),
                border: Border.all(
                  color: isInbound
                      ? colors.glassBorder.withValues(
                          alpha: visual.isDark ? 0.20 : 0.35,
                        )
                      : Colors.white.withValues(alpha: 0.35),
                  width: 0.75,
                ),
              ),
              child: Column(
                crossAxisAlignment: isInbound
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.item.isGroup &&
                      isInbound &&
                      sender != null &&
                      sender.isNotEmpty &&
                      sender != widget.item.displayName) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 11,
                          color: _getSenderColor(sender),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sender,
                          style: TextStyle(
                            color: _getSenderColor(sender),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                  ConversationMediaBubble(
                    text: text,
                    isInbound: isInbound,
                    visual: visual,
                    timestampMs: timestampMs,
                  ),
                  const SizedBox(height: 2),
                  MessageEventTime(
                    timestampMs: timestampMs,
                    color: isInbound
                        ? visual.textMuted
                        : visual.onAccent.withValues(alpha: 0.80),
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
