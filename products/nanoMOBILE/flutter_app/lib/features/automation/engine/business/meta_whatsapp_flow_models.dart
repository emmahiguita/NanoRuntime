// meta_whatsapp_flow_models.dart
//
// QUÉ HACE:
// Modelos oficiales para mensajes interactivos de WhatsApp Flows (Meta Cloud API v21+)
// y decodificación tipada de respuestas `nfm_reply` enviadas por el cliente.
//
// CÓMO FUNCIONA:
// - [MetaWhatsAppFlowRequest] construye el payload oficial `type: "interactive"` con
//   `interactive.type: "flow"` y `flow_message_version: "3"`, aplicando las restricciones
//   de Meta (CTA <= 20 caracteres, token no vacío y pantalla inicial válida).
// - [MetaWhatsAppFlowSubmission] parsea el `response_json` recibido cuando un cliente
//   completa un formulario nativo de pedido, reserva o soporte.
//
// POR QUÉ:
// Completa el Punto 6: sustituye los largos cuestionarios de texto plano en Negocio
// por formularios nativos interactivos de WhatsApp Flows sin errores de tipeo.

library;

import 'dart:convert';

/// Pantallas estándar de negocio soportadas en WhatsApp Flows.
enum MetaWhatsAppFlowScreen {
  orderCheckout('ORDER_CHECKOUT'),
  productSelection('PRODUCT_SELECTION'),
  appointmentBooking('APPOINTMENT_BOOKING'),
  supportTicket('SUPPORT_TICKET');

  final String screenId;
  const MetaWhatsAppFlowScreen(this.screenId);
}

/// Solicitud tipada para despachar un WhatsApp Flow interactivo oficial.
final class MetaWhatsAppFlowRequest {
  final String recipientPhone;
  final String flowId;
  final String flowToken;
  final String headerText;
  final String bodyText;
  final String footerText;
  final String ctaLabel;
  final MetaWhatsAppFlowScreen screen;
  final Map<String, Object?> initialData;

  const MetaWhatsAppFlowRequest({
    required this.recipientPhone,
    required this.flowId,
    required this.flowToken,
    required this.headerText,
    required this.bodyText,
    this.footerText = 'Completa los datos de forma segura',
    required this.ctaLabel,
    this.screen = MetaWhatsAppFlowScreen.orderCheckout,
    this.initialData = const {},
  });

  /// Valida las invariantes exigidas por Meta Cloud API antes de enviar.
  bool get isValid {
    final phone = recipientPhone.trim().replaceAll(RegExp(r'[\s()+-]'), '');
    final cta = ctaLabel.trim();
    return RegExp(r'^[1-9]\d{7,14}$').hasMatch(phone) &&
        flowId.trim().isNotEmpty &&
        flowToken.trim().isNotEmpty &&
        bodyText.trim().isNotEmpty &&
        cta.isNotEmpty &&
        cta.length <= 20;
  }

  /// Genera el payload JSON oficial de Meta Cloud API para `POST /messages`.
  Map<String, dynamic> toGraphApiJson() {
    if (!isValid) {
      throw StateError('MetaWhatsAppFlowRequest incumple las reglas de Meta');
    }
    final cleanPhone = recipientPhone.trim().replaceAll(RegExp(r'[\s()+-]'), '');
    return {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': cleanPhone,
      'type': 'interactive',
      'interactive': {
        'type': 'flow',
        if (headerText.trim().isNotEmpty)
          'header': {'type': 'text', 'text': headerText.trim()},
        'body': {'text': bodyText.trim()},
        if (footerText.trim().isNotEmpty)
          'footer': {'text': footerText.trim()},
        'action': {
          'name': 'flow',
          'parameters': {
            'flow_message_version': '3',
            'flow_token': flowToken.trim(),
            'flow_id': flowId.trim(),
            'flow_cta': ctaLabel.trim(),
            'flow_action': 'navigate',
            'flow_action_payload': {
              'screen': screen.screenId,
              if (initialData.isNotEmpty) 'data': initialData,
            },
          },
        },
      },
    };
  }
}

/// Respuesta estructurada enviada por el usuario al completar un WhatsApp Flow (`nfm_reply`).
final class MetaWhatsAppFlowSubmission {
  final String flowToken;
  final String? customerName;
  final String? deliveryAddress;
  final String? selectedProductId;
  final int? quantity;
  final String? paymentMethod;
  final String? notes;
  final Map<String, dynamic> rawFields;

  const MetaWhatsAppFlowSubmission({
    required this.flowToken,
    this.customerName,
    this.deliveryAddress,
    this.selectedProductId,
    this.quantity,
    this.paymentMethod,
    this.notes,
    this.rawFields = const {},
  });

  /// Parsea de forma segura el campo `response_json` de un webhook `nfm_reply`.
  static MetaWhatsAppFlowSubmission? tryParse(String? responseJson) {
    if (responseJson == null || responseJson.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(responseJson);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      final token = '${map['flow_token'] ?? map['flowToken'] ?? ''}'.trim();
      final qtyRaw = map['quantity'] ?? map['cantidad'];
      final qty = qtyRaw is num
          ? qtyRaw.toInt()
          : int.tryParse('${qtyRaw ?? ''}');
      return MetaWhatsAppFlowSubmission(
        flowToken: token,
        customerName: _str(map['customer_name'] ?? map['nombre']),
        deliveryAddress: _str(map['delivery_address'] ?? map['direccion']),
        selectedProductId: _str(map['product_id'] ?? map['producto_id']),
        quantity: qty,
        paymentMethod: _str(map['payment_method'] ?? map['metodo_pago']),
        notes: _str(map['notes'] ?? map['notas']),
        rawFields: Map.unmodifiable(map),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _str(Object? value) {
    final s = '${value ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}
