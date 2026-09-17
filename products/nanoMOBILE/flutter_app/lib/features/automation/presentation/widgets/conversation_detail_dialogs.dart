part of 'conversation_detail_sheet.dart';

/// Diálogos y modales de soporte para ConversationDetailSheet (formularios, adjuntos y opciones).
extension _ConversationDetailDialogs on _ConversationDetailSheetState {
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
                const SizedBox(height: 8),
                Text(
                  'Para despachar a este contacto sin abrir WhatsApp en pantalla completa, activa el servicio de automatización en segundo plano.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop('settings');
                      await share.openAccessibilitySettings();
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 18),
                    label: const Text(
                      'Activar Automatización en 1 Tap',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop('sent_whatsapp');
                      await share.openChat(
                        contact: contact,
                        text: text,
                        packageName: widget.item.packageName,
                        autoSend: false,
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'Abrir en WhatsApp por esta vez',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop('cancel'),
                  child: Text(
                    'Permanecer en Nano',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFormPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final forms = [
          {
            'title': '📋 Registro de Contacto / Cliente',
            'desc': 'Solicita nombre, correo y servicio de interés',
            'text':
                '📋 *Formulario de Registro*\nHola, para brindarte una atención personalizada, ¿podrías indicarnos:\n1. Tu nombre completo:\n2. Correo electrónico:\n3. ¿Qué servicio o producto te interesa?',
          },
          {
            'title': '⭐ Encuesta de Calidad / Satisfacción',
            'desc': 'Pregunta rápida de calificación y comentarios',
            'text':
                '⭐ *Encuesta de Calidad*\n¡Hola! Tu opinión nos importa mucho:\n¿Cómo calificarías nuestra atención del 1 al 5 (donde 5 es excelente)?\nComentarios o sugerencias:',
          },
          {
            'title': '📦 Confirmación de Cita o Pedido',
            'desc': 'Detalles de fecha, horario y dirección',
            'text':
                '📦 *Confirmación de Pedido / Cita*\nHola, para confirmar tu solicitud necesitamos:\n• Fecha y hora preferida:\n• Dirección de entrega / ubicación:\n• Notas especiales:',
          },
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enviar Formulario Interactivo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona una plantilla estructurada para enviarle a este contacto.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                ...forms.map(
                  (f) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    title: Text(
                      f['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      f['desc']!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF00FF88),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _safeSetState(() {
                        _inputController.text = f['text']!;
                        _statusText = 'Formulario insertado listo para enviar';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentMenu() {
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
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00FF88),
                  child: Icon(Icons.image_rounded, color: Colors.black),
                ),
                title: const Text('Enviar Imagen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Galería o fotos guardadas', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF007AFF),
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                ),
                title: const Text('Enviar Documento PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Archivos PDF del dispositivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachPdf();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.assignment_rounded, color: Colors.white),
                ),
                title: const Text('Formulario Interactivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Plantilla de registro o encuesta rápida', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showFormPicker();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.attach_file_rounded, color: Colors.white),
                ),
                title: const Text('Cualquier archivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Archivos del dispositivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachAndShareFile();
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
            Text(
              'Destino no verificable',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'No hay una notificación activa en barra ni un número de teléfono internacional registrado para $contactName.\n\n'
          'Por seguridad y para evitar que el mensaje se envíe a otro chat abierto, Nano no enviará a ciegas.',
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

  Future<void> _attachImage() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando imagen para compartir...';
      });

      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(file.path!) ?? file.path!;
      final caption = _inputController.text.trim();
      final contact = widget.item.conversationId.isNotEmpty
          ? widget.item.conversationId
          : widget.item.displayName;

      final ok = await share.shareFile(
        path: stablePath,
        contact: contact,
        caption: caption,
        packageName: widget.item.packageName,
      );

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para enviar imagen'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() {
        _statusText = 'Error al adjuntar imagen: $e';
      });
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  Future<void> _attachPdf() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando PDF para compartir...';
      });

      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(file.path!) ?? file.path!;
      final caption = _inputController.text.trim();
      final contact = widget.item.conversationId.isNotEmpty
          ? widget.item.conversationId
          : widget.item.displayName;

      final ok = await share.shareFile(
        path: stablePath,
        contact: contact,
        caption: caption,
        packageName: widget.item.packageName,
      );

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para enviar PDF'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() {
        _statusText = 'Error al adjuntar PDF: $e';
      });
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  Future<void> _attachAndShareFile() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando archivo para compartir...';
      });

      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(file.path!) ?? file.path!;
      final caption = _inputController.text.trim();
      final contact = widget.item.conversationId.isNotEmpty
          ? widget.item.conversationId
          : widget.item.displayName;

      final ok = await share.shareFile(
        path: stablePath,
        contact: contact,
        caption: caption,
        packageName: widget.item.packageName,
      );

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para adjuntar archivo'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() {
        _statusText = 'Error al adjuntar: $e';
      });
    } finally {
      _safeSetState(() => _busy = false);
    }
  }
}
