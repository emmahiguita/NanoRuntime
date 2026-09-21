part of 'conversation_detail_sheet.dart';

/// [ConversationDetailDialogs]
///
/// QUÉ HACE:
/// Despliega modales de soporte, advertencia de seguridad para destinos sin verificar,
/// opciones de envío alternativo y plantillas de formularios rápidos.
///
/// CÓMO FUNCIONA:
/// 1. `_showMissingPhoneDialog`: Advierte al usuario cuando un contacto no tiene teléfono
///    ni notificación en segundo plano, evitando disparar mensajes a ciegas a WhatsApp.
/// 2. `_showNoA11yOptionsModal`: Ofrece opciones para enviar por WhatsApp cuando el servicio
///    de accesibilidad no está activo en el dispositivo.
/// 3. `_showFormPicker`: Permite insertar plantillas de recopilación de datos (registro, encuesta).
///
/// POR QUÉ:
/// Protege la privacidad del usuario, asegura confirmaciones transparentes antes de cualquier
/// acción física y mantiene el código desacoplado y estrictamente menor a 200 líneas.
extension ConversationDetailDialogs on _ConversationDetailSheetState {
  Future<String?> _showNoA11yOptionsModal(
    BuildContext context,
    WhatsAppMediaShare share,
    String contact,
    String text,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: const Color(0xEB0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF00FF88),
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enviar sin salir de Nano',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Para enviar automáticamente en segundo plano sin cambiar de app, activa el Servicio de Accesibilidad de Nano. De lo contrario, abrirá el chat directamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Activar Retorno Automático'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop('open_settings');
                    await share.openAccessibilitySettings();
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Abrir chat en WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop('sent_whatsapp');
                    await share.openChat(contact: contact, text: text, autoSend: false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFormPicker() {
    final forms = [
      {'title': 'Formulario de Contacto', 'desc': 'Nombre, correo, teléfono y consulta', 'text': 'Por favor completa tus datos:\n- Nombre:\n- Correo:\n- Consulta:'},
      {'title': 'Encuesta de Satisfacción', 'desc': 'Calificación 1-5 y comentarios', 'text': '¿Cómo calificarías nuestra atención del 1 al 5?\nTu opinión nos ayuda a mejorar.'},
      {'title': 'Confirmación de Pedido', 'desc': 'Detalles de entrega y método de pago', 'text': 'Confirma los detalles de tu pedido:\n- Dirección:\n- Forma de pago:\n- Horario de entrega:'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in forms)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF00FF88),
                    child: Icon(Icons.description_rounded, color: Colors.black),
                  ),
                  title: Text(f['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(f['desc']!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _safeSetState(() {
                      _inputController.text = f['text']!;
                      _statusText = 'Formulario insertado';
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMissingPhoneDialog(BuildContext context, String contactName) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFFF9500), size: 24),
            SizedBox(width: 8),
            Text('Destino no verificable', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'No hay una notificación activa en barra ni un número registrado para $contactName.\n\n'
          'Por seguridad, Nano no enviará a ciegas para evitar enviar a otro chat.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF007AFF))),
          ),
        ],
      ),
    );
  }
}
