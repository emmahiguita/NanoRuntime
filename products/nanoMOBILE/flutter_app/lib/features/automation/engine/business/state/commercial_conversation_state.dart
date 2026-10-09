// commercial_conversation_state.dart
//
// QUÉ HACE:
// Snapshot inmutable del estado comercial de una conversación activa.
//
// CÓMO FUNCIONA:
// - Registra ID de conversación, etapa del embudo, producto en foco, slots pendientes,
//   artículos en carrito, versión de catálogo utilizada y timestamp de interacción.
//
// POR QUÉ:
// Permite que Nano mantenga el hilo conductor de una venta a lo largo de múltiples
// mensajes y días, sin perder contexto ni reiniciar la interacción.

library;

import 'commercial_cart_item.dart';
import 'commercial_funnel_stage.dart';

final class CommercialConversationState {
  final String conversationId;
  final CommercialFunnelStage stage;
  final String? focusedProductId;
  final String? pendingSlot; // Ej: 'color', 'talla', 'direccion_envio'
  final List<CommercialCartItem> cart;
  final DateTime lastInteraction;
  final int factsVersion;
  final bool isHumanEscalated;
  final String? escalationReason;

  const CommercialConversationState({
    required this.conversationId,
    this.stage = CommercialFunnelStage.inquiry,
    this.focusedProductId,
    this.pendingSlot,
    this.cart = const [],
    required this.lastInteraction,
    this.factsVersion = 1,
    this.isHumanEscalated = false,
    this.escalationReason,
  });

  double get cartTotal =>
      cart.fold(0.0, (sum, item) => sum + item.subtotal);

  int get cartItemsCount =>
      cart.fold(0, (sum, item) => sum + item.quantity);

  CommercialConversationState copyWith({
    CommercialFunnelStage? stage,
    String? focusedProductId,
    String? pendingSlot,
    List<CommercialCartItem>? cart,
    DateTime? lastInteraction,
    int? factsVersion,
    bool? isHumanEscalated,
    String? escalationReason,
  }) => CommercialConversationState(
    conversationId: conversationId,
    stage: stage ?? this.stage,
    focusedProductId: focusedProductId ?? this.focusedProductId,
    pendingSlot: pendingSlot ?? this.pendingSlot,
    cart: cart ?? this.cart,
    lastInteraction: lastInteraction ?? this.lastInteraction,
    factsVersion: factsVersion ?? this.factsVersion,
    isHumanEscalated: isHumanEscalated ?? this.isHumanEscalated,
    escalationReason: escalationReason ?? this.escalationReason,
  );

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'stage': stage.name,
    if (focusedProductId != null) 'focusedProductId': focusedProductId,
    if (pendingSlot != null) 'pendingSlot': pendingSlot,
    'cart': [for (final item in cart) item.toJson()],
    'lastInteraction': lastInteraction.toIso8601String(),
    'factsVersion': factsVersion,
    'isHumanEscalated': isHumanEscalated,
    if (escalationReason != null) 'escalationReason': escalationReason,
  };

  factory CommercialConversationState.fromJson(Map<String, dynamic> json) =>
      CommercialConversationState(
        conversationId: (json['conversationId'] as String?) ?? '',
        stage: _parseStage(json['stage'] as String?),
        focusedProductId: json['focusedProductId'] as String?,
        pendingSlot: json['pendingSlot'] as String?,
        cart: [
          for (final item in (json['cart'] as List?) ?? const [])
            if (item is Map) CommercialCartItem.fromJson(item.cast<String, dynamic>()),
        ],
        lastInteraction: DateTime.tryParse((json['lastInteraction'] as String?) ?? '') ??
            DateTime.now(),
        factsVersion: (json['factsVersion'] as num?)?.toInt() ?? 1,
        isHumanEscalated: (json['isHumanEscalated'] as bool?) ?? false,
        escalationReason: json['escalationReason'] as String?,
      );

  static CommercialFunnelStage _parseStage(String? name) {
    if (name == null) return CommercialFunnelStage.inquiry;
    for (final s in CommercialFunnelStage.values) {
      if (s.name == name) return s;
    }
    return CommercialFunnelStage.inquiry;
  }
}
