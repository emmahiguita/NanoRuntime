part of 'whatsapp_automation_menu.dart';

/// Posee el formulario y sus recursos, nunca el ejecutor. El adjunto se elige
/// desde el +; este menú únicamente solicita a quién dirigir cada acción.
class _WhatsAppActionsState extends State<_WhatsAppActions> {
  final _recipient = TextEditingController();
  _WhatsAppMenuAction? _action;
  String? _error;
  bool _closing = false;

  /// Cambia la acción sin resolver contactos ni ejecutar operaciones externas.
  void _select(_WhatsAppMenuAction action) => setState(() {
    _action = action;
    _error = null;
  });

  /// Regresa a las funciones o cierra su única ruta, sin otro nivel vacío.
  void _back() {
    if (_closing) return;
    if (_action == null) {
      _closing = true;
      Navigator.of(context).pop();
    } else {
      setState(() {
        _action = null;
        _error = null;
      });
    }
  }

  /// Devuelve el texto literal. Resolver coincidencias y verificar el chat es
  /// responsabilidad del ejecutor; el menú no elige contactos por aproximación.
  String? _target() {
    final value = _recipient.text.trim();
    if (value.isEmpty || value.contains('"') || value.contains('\n')) {
      setState(() => _error = 'Indica nombre, teléfono o @usuario.');
      return null;
    }
    return value;
  }

  // Un doble toque durante la salida no puede cerrar la pantalla de Nano.
  void _stage(String command) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(command);
  }

  /// Prepara la orden existente, sin abrir un segundo selector ni enviar nada.
  void _prepare() {
    if (_closing) return;
    final target = _target();
    if (target == null) return;
    switch (_action) {
      case _WhatsAppMenuAction.open:
        _stage('Abre el chat de ${jsonEncode(target)}');
      case _WhatsAppMenuAction.compose:
        _stage('Envía a ${jsonEncode(target)}: ');
      case _WhatsAppMenuAction.attach:
        final file = widget.attachment;
        if (file != null) _stage(file.draftFor(target));
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) => _buildMenu(context);
  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }
}
