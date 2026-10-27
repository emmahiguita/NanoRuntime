import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../engine/business/meta_templates_api.dart';
import 'meta_template_send_picker.dart';
import 'meta_attachment_choice.dart';
part 'meta_manual_composer_view.dart';

/// Editor manual: solo el botón Enviar inicia una escritura externa.
/// Una operación a la vez; ante incertidumbre conserva ID y contenido para no duplicar.
class MetaManualComposer extends ConsumerStatefulWidget {
  const MetaManualComposer({
    super.key,
    required this.api,
    required this.peer,
    required this.lineLabel,
    required this.onAccepted,
  });
  final MetaTemplatesApi api;
  final String peer, lineLabel;
  final Future<void> Function() onAccepted;
  @override
  ConsumerState<MetaManualComposer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<MetaManualComposer> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _requestId, _notice, _mediaId;
  PlatformFile? _file;
  Map<String, dynamic>? _template;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _mime(String name) => switch (name.split('.').last.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    'm4a' => 'audio/mp4',
    _ => 'application/octet-stream',
  };

  /// Selección explícita; todavía no sube ni envía el archivo.
  Future<void> _attach() async {
    setState(() => _busy = true);
    try {
      final file = await chooseMetaAttachment(context, ref);
      if (file != null && mounted) {
        setState(() {
          _file = file;
          _template = null;
          _mediaId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Selecciona un solo archivo legible de hasta 6 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseTemplate() async {
    final template = await pickMetaSendTemplate(context, widget.api);
    if (template != null && mounted) {
      setState(() {
        _template = template;
        _file = null;
      });
    }
  }

  Future<void> _send() async {
    if (_busy ||
        (_text.text.trim().isEmpty && _file == null && _template == null)) {
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    // Un ID criptográficamente aleatorio evita colisiones entre dispositivos.
    _requestId ??= List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    try {
      final body = <String, dynamic>{
        'to': widget.peer,
        'text': _text.text.trim(),
      };
      if (_template != null) {
        body['type'] = 'template';
        body['template'] = _template;
      }
      if (_file != null) {
        final file = _file!;
        final mime = _mime(file.name);
        final id = _mediaId ??= await widget.api.uploadMedia(
          file.name,
          mime,
          file.bytes!,
        );
        final type = mime.startsWith('image/')
            ? 'image'
            : mime.startsWith('audio/')
            ? 'audio'
            : mime.startsWith('video/')
            ? 'video'
            : 'document';
        body['type'] = type;
        body[type] = {
          'id': id,
          if (type == 'document') 'filename': file.name,
          if (type != 'audio' && _text.text.trim().isNotEmpty)
            'caption': _text.text.trim(),
        };
      }
      final id = await widget.api.sendManual(body, _requestId!);
      if (!mounted) return;
      setState(() {
        _requestId = null;
        _mediaId = null;
        _file = null;
        _template = null;
        _text.clear();
        _notice = 'Aceptado por Meta: $id. Entrega pendiente.';
      });
      await widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'No se confirmó el envío. El ID se conserva; '
              'consulta el historial antes de volver a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildEditor(context);
}
