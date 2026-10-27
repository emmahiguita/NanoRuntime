// channel_adapter.dart
//
// QUÉ HACE:
// Contrato base para todos los adaptadores de transporte de Nano Messaging Core.
//
// CÓMO FUNCIONA:
// - Cada adaptador traduce desde el formato nativo de su plataforma a `NanoIncomingMessage`
//   y desde `NanoOutgoingMessage` hacia el canal físico.
// - Declara sus `MessagingCapabilities` reales.
//
// POR QUÉ:
// Mantiene aislada la lógica de cada plataforma (WhatsApp, Telegram, etc.) de Nano Negocio.

library;

import '../../../domain/messaging_platform.dart';
import 'delivery_result.dart';
import 'messaging_capabilities.dart';
import 'nano_outgoing_message.dart';

abstract interface class ChannelAdapter {
  MessagingPlatform get platform;
  MessagingCapabilities get capabilities;

  /// Entrega un mensaje saliente a través del canal físico.
  Future<DeliveryResult> deliver(NanoOutgoingMessage message);

  /// Indica si el canal se encuentra actualmente disponible / conectado.
  Future<bool> isAvailable();
}
