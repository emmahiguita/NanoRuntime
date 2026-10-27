part of 'mcp_store_components.dart';

/// Tienda MCP: form; conserva validación y almacenamiento seguro.
Widget _mcpConnectionForm(
  AutomationVisualPalette visual,
  TextEditingController idController,
  TextEditingController nameController,
  TextEditingController endpointController,
  TextEditingController tokenController,
  String? errorMsg,
) => SizedBox(
  width: 360,
  child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identificador único del servidor:',
          style: TextStyle(color: visual.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: idController,
          style: TextStyle(
            color: visual.text,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'calendar-mcp',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Nombre para mostrar:',
          style: TextStyle(color: visual.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: nameController,
          style: TextStyle(color: visual.text, fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Mi calendario',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Endpoint URL del servidor MCP:',
          style: TextStyle(color: visual.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: endpointController,
          style: TextStyle(
            color: visual.text,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: visual.inputFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Token de autorización (opcional):',
          style: TextStyle(color: visual.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: tokenController,
          obscureText: true,
          style: TextStyle(color: visual.text, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: visual.inputFill,
            hintText: 'Bearer token o API Key',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (errorMsg != null) ...[
          const SizedBox(height: 10),
          Text(
            errorMsg,
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ],
      ],
    ),
  ),
);
