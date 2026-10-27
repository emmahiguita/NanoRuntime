part of 'tool_registry.dart';

/// Herramientas registradas: conserva sintaxis, timeout y compatibilidad.
const _toolDefinitions1 = <ToolDefinition>[
  ToolDefinition(
    name: 'whatsapp.open_chat',
    timeout: Duration(seconds: 15),
    description:
        'Abrir un chat de WhatsApp con un contacto o número telefónico',
    promptSyntax:
        '{"tool":"whatsapp.open_chat","contact":"<contacto_o_numero>","text":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'whatsapp.send_message',
    // Incluye resolución, intento nativo y verificación acotada del regreso.
    timeout: Duration(seconds: 35),
    description: 'Enviar un mensaje por WhatsApp a un contacto o número',
    promptSyntax:
        '{"tool":"whatsapp.send_message","contact":"<contacto_o_numero>","text":"<texto>"}',
  ),
  ToolDefinition(
    name: 'whatsapp.contacts',
    timeout: Duration(seconds: 15),
    description: 'Consultar o buscar contactos de WhatsApp en el dispositivo',
    promptSyntax: '{"tool":"whatsapp.contacts","query":"<nombre_o_numero>"}',
  ),
  ToolDefinition(
    name: 'whatsapp.share_file',
    timeout: Duration(seconds: 35),
    description: 'Compartir un documento, archivo, foto o video por WhatsApp',
    promptSyntax:
        '{"tool":"whatsapp.share_file","contact":"<contacto_o_numero>","path":"<ruta_archivo>","caption":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'telegram.open_chat',
    timeout: Duration(seconds: 15),
    description: 'Abrir un chat de Telegram con un contacto, usuario o número',
    promptSyntax:
        '{"tool":"telegram.open_chat","contact":"<contacto_o_usuario>","text":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'telegram.send_message',
    timeout: Duration(seconds: 20),
    description: 'Enviar un mensaje por Telegram a un contacto o usuario',
    promptSyntax:
        '{"tool":"telegram.send_message","contact":"<contacto_o_usuario>","text":"<texto>"}',
  ),
  ToolDefinition(
    name: 'telegram.contacts',
    timeout: Duration(seconds: 15),
    description: 'Consultar o buscar contactos para Telegram en el dispositivo',
    promptSyntax: '{"tool":"telegram.contacts","query":"<nombre_o_numero>"}',
  ),
  ToolDefinition(
    name: 'telegram.share_file',
    timeout: Duration(seconds: 25),
    description: 'Compartir un archivo, documento o foto por Telegram',
    promptSyntax:
        '{"tool":"telegram.share_file","contact":"<contacto_o_usuario>","path":"<ruta_archivo>","caption":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'messenger.open_chat',
    timeout: Duration(seconds: 15),
    description:
        'Abrir un chat de Facebook Messenger con un contacto o usuario',
    promptSyntax:
        '{"tool":"messenger.open_chat","contact":"<contacto_o_usuario>","text":"<texto_opcional>"}',
  ),
  ToolDefinition(
    name: 'messenger.send_message',
    timeout: Duration(seconds: 20),
    description: 'Enviar un mensaje por Facebook Messenger a un contacto',
    promptSyntax:
        '{"tool":"messenger.send_message","contact":"<contacto_o_usuario>","text":"<texto>"}',
  ),
];
