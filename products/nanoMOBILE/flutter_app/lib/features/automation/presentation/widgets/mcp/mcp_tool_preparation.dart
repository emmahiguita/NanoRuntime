import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../engine/mcp/mcp_client_port.dart';
import '../../../engine/mcp/mcp_schema_validator.dart';

/// Prepara argumentos comprobados y copia un comando para el agente.
/// No ejecuta herramientas: la llamada posterior conserva la gobernanza existente.
Future<void> showMcpToolPreparation(BuildContext context, McpRemoteTool tool) =>
    showDialog<void>(
      context: context,
      builder: (_) => _McpToolPreparation(tool: tool),
    );

class _McpToolPreparation extends StatefulWidget {
  const _McpToolPreparation({required this.tool});
  final McpRemoteTool tool;
  @override
  State<_McpToolPreparation> createState() => _McpToolPreparationState();
}

class _McpToolPreparationState extends State<_McpToolPreparation> {
  final _arguments = TextEditingController(text: '{}');
  String? _feedback;
  bool _busy = false;
  @override
  void dispose() {
    _arguments.dispose();
    super.dispose();
  }

  /// Valida fuera del hilo de dibujo antes de copiar. Nunca inventa valores obligatorios.
  Future<void> _copy() async {
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final decoded = jsonDecode(_arguments.text);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final problems = await McpSchemaValidator.validate(
        widget.tool.inputSchema,
        decoded,
      );
      if (!mounted) return;
      if (problems.isNotEmpty) {
        setState(() => _feedback = problems.join('\n'));
        return;
      }
      await Clipboard.setData(
        ClipboardData(
          text: '@mcp call ${widget.tool.qualifiedName} ${jsonEncode(decoded)}',
        ),
      );
      if (mounted) {
        setState(
          () => _feedback =
              'Comando copiado. Pégalo en el agente; allí se revisará su autorización.',
        );
      }
    } on FormatException {
      if (mounted) {
        setState(() => _feedback = 'Escribe un objeto JSON completo y válido.');
      }
    } on Object {
      if (mounted) {
        setState(() => _feedback = 'No se pudo preparar el comando.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Preparar llamada'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(widget.tool.qualifiedName),
            const SizedBox(height: 12),
            Text(widget.tool.description),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver contrato de argumentos'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(widget.tool.inputSchema),
                ),
              ],
            ),
            TextField(
              controller: _arguments,
              minLines: 4,
              maxLines: 10,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Argumentos JSON',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Copiar no ejecuta. Enviar el comando al agente autoriza esa llamada concreta; los planes propuestos por el modelo requieren confirmación para efectos sensibles.',
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_feedback!),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: _busy ? null : _copy,
        child: Text(_busy ? 'Validando…' : 'Validar y copiar'),
      ),
    ],
  );
}
