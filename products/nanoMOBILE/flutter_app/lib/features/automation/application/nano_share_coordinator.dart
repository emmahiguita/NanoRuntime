import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/nano_share_payload.dart';
import '../domain/phone_number_sanitizer.dart';
import '../domain/whatsapp_contact.dart';
import 'whatsapp_contacts_provider.dart';
import '../presentation/business/share/nano_contact_picker_sheet.dart';

/// Coordinador de compartición de contenidos (productos, archivos y mensajes) de Nano.
///
/// QUÉ HACE:
/// - Orquesta la selección de destinatarios y el despacho hacia WhatsApp o aplicaciones externas.
/// - Aplica normalización telefónica E.164 y Click to Chat oficial (wa.me) para números específicos.
/// - Registra contactos frecuentes en el historial de recientes de Nano y publica shortcuts nativos.
///
/// CÓMO SE CONECTA:
/// - Invocado desde la tienda (BusinessStoreProductActions) y la biblioteca de archivos (BusinessDocumentActions).
/// - Abre la hoja flotante NanoContactPickerSheet.
///
/// POR QUÉ:
/// - Aplica SOLID aislando la lógica de transporte y despacho fuera de los widgets (< 160 líneas).
final class NanoShareCoordinator {
  NanoShareCoordinator._();

  /// Despliega la ventana flotante de selección de contacto y destinos.
  static Future<void> showPicker({
    required BuildContext context,
    required NanoSharePayload payload,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => NanoContactPickerSheet(payload: payload),
    );
  }

  /// Despacha el contenido hacia un contacto específico de la agenda o reciente.
  static Future<bool> dispatchToContact({
    required BuildContext context,
    required WhatsAppContact contact,
    required NanoSharePayload payload,
    WidgetRef? ref,
  }) async {
    // 1. Guardar en recientes
    if (ref != null) {
      ref.read(recentShareContactsProvider.notifier).rememberContact(contact);
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final cleanDigits = PhoneNumberSanitizer.sanitizeForWhatsApp(contact.number);

    // 2. Si tiene archivo adjunto (foto, video, PDF)
    if (payload.hasMedia && payload.mediaFile != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [payload.mediaFile!],
            text: payload.text,
            subject: payload.title,
          ),
        );
        return true;
      } catch (e) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar el archivo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    // 3. Si es solo texto y tiene número válido: Click to Chat directo
    if (PhoneNumberSanitizer.isValidE164(cleanDigits)) {
      final uri = Uri.parse(
        'https://wa.me/$cleanDigits?text=${Uri.encodeComponent(payload.text)}',
      );
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await _fallbackSystemShare(payload);
        }
        return launched;
      } catch (_) {
        await _fallbackSystemShare(payload);
        return false;
      }
    }

    // 4. Si no tiene número válido directo, usa fallback general
    await _fallbackSystemShare(payload);
    return true;
  }

  /// Despacha directamente a la app de WhatsApp sin contacto predeterminado (ideal para grupos).
  static Future<void> dispatchDirectApp({
    required BuildContext context,
    required NanoSharePayload payload,
    bool isBusiness = false,
  }) async {
    if (payload.hasMedia && payload.mediaFile != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [payload.mediaFile!],
          text: payload.text,
          subject: payload.title,
        ),
      );
      return;
    }

    // Intenta enviar mediante intent directo o fallback de sistema
    await _fallbackSystemShare(payload);
  }

  /// Despacha mediante el Android Sharesheet estándar del sistema.
  static Future<void> dispatchToSystemSharesheet({
    required NanoSharePayload payload,
  }) async {
    await _fallbackSystemShare(payload);
  }

  static Future<void> _fallbackSystemShare(NanoSharePayload payload) async {
    if (payload.hasMedia && payload.mediaFile != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [payload.mediaFile!],
          text: payload.text,
          subject: payload.title,
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: payload.text,
          subject: payload.title,
        ),
      );
    }
  }
}
