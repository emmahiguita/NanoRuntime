part of 'conversation_detail_sheet.dart';

extension ConversationDetailFormPicker on _ConversationDetailSheetState {
  void _showFormPicker() {
    final visual = AutomationVisual.of(context);
    final accentGreen = visual.isDark
        ? const Color(0xFF00FF88)
        : const Color(0xFF059669);
    final forms = [
      {
        'title': 'Formulario de Contacto',
        'desc': 'Nombre, correo, teléfono y consulta',
        'text':
            'Por favor completa tus datos:\n- Nombre:\n- Correo:\n- Consulta:',
      },
      {
        'title': 'Encuesta de Satisfacción',
        'desc': 'Calificación 1-5 y comentarios',
        'text':
            '¿Cómo calificarías nuestra atención del 1 al 5?\nTu opinión nos ayuda a mejorar.',
      },
      {
        'title': 'Confirmación de Pedido',
        'desc': 'Detalles de entrega y método de pago',
        'text':
            'Confirma los detalles de tu pedido:\n- Dirección:\n- Forma de pago:\n- Horario de entrega:',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final form in forms)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accentGreen,
                    child: Icon(
                      Icons.description_rounded,
                      color: visual.isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  title: Text(
                    form['title']!,
                    style: TextStyle(
                      color: visual.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    form['desc']!,
                    style: TextStyle(color: visual.textMuted, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _safeSetState(() {
                      _inputController.text = form['text']!;
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
}
