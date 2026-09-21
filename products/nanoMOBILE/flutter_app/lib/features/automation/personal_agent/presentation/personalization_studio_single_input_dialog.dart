part of 'personalization_studio_screen.dart';

/// PERSONALIZATION-STUDIO-SINGLE-INPUT-DIALOG — Diálogo con ciclo de vida seguro.
///
/// **QUÉ HACE:**
/// Presenta un cuadro modal con campo de texto para captura de datos
/// (nombres de contactos, respuestas posibles) devolviendo el texto limpio.
///
/// **CÓMO FUNCIONA:**
/// Encapsula el TextEditingController dentro de su propio State (StatefulWidget)
/// y lo libera en dispose() solo después de que el modal haya salido del árbol.
///
/// **POR QUÉ:**
/// Previene la aserción de Flutter '_dependents.isEmpty: is not true' provocada
/// al disponer controladores mientras el diálogo aún se anima en el Navigator.
class _SingleInputDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String? hintText;
  final String confirmText;
  final int maxLines;
  final int maxLength;

  const _SingleInputDialog({
    required this.title,
    required this.labelText,
    this.hintText,
    this.confirmText = 'Guardar',
    this.maxLines = 1,
    this.maxLength = 100,
  });

  @override
  State<_SingleInputDialog> createState() => _SingleInputDialogState();
}

class _SingleInputDialogState extends State<_SingleInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x22FFFFFF), width: 0.8),
      ),
      backgroundColor: const Color(0xFF162036),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF00E676)),
          hintStyle: const TextStyle(fontSize: 10.5, color: Colors.white38),
          filled: true,
          fillColor: const Color(0x0CFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x8000E676)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final val = _controller.text.trim();
            Navigator.of(context).pop(val);
          },
          child: Text(
            widget.confirmText,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
