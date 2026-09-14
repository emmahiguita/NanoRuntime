import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/chat_provider.dart';

/// Despachador inteligente de comandos y búsquedas universales de Nano AI.
///
/// Aplica el principio de Responsabilidad Única (SRP) para analizar
/// intenciones de texto introducidas en la barra cósmica y enrutar
/// al destino adecuado (Terminal, Automatización, Modelos, Ajustes o Chat).
///
/// Comprende desde un saludo ("hola") hasta párrafos extensos de texto y código.
class NanoSearchDispatcher {
  const NanoSearchDispatcher._();

  static void dispatch(BuildContext context, String rawQuery, {WidgetRef? ref}) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final lower = query.toLowerCase();

    // 1. Detección de comandos de consola/terminal explícitos
    if (query.startsWith('/') ||
        query.startsWith('>') ||
        query.startsWith('\$') ||
        _isTerminalCommand(lower)) {
      final cleanCmd = query.replaceFirst(RegExp(r'^[/ >\$]+'), '').trim();
      context.push('/terminal/shell?cmd=${Uri.encodeComponent(cleanCmd.isEmpty ? query : cleanCmd)}');
      return;
    }

    // 2. Navegación directa a Terminal / Shell
    if ((lower == 'terminal' || lower == 'consola' || lower == 'shell' || lower == 'kali') && query.length < 20) {
      context.push('/terminal/shell');
      return;
    }

    // 3. Comandos directos de navegación rápida a Ajustes
    if ((lower == 'ajustes' || lower == 'configuración' || lower == 'config' || lower == 'tema') && query.length < 20) {
      context.go('/settings');
      return;
    }

    // 4. Comandos directos de navegación rápida a Modelos
    if ((lower == 'modelos' || lower == 'descargar modelos' || lower == 'llm') && query.length < 25) {
      context.go('/models');
      return;
    }

    // 5. Comandos directos a Automatización
    if ((lower == 'automatización' || lower == 'automatizacion' || lower == 'automation' || lower == 'whatsapp') && query.length < 25) {
      context.push('/automation');
      return;
    }

    // 6. Conversación Inteligente en el Chat de Nano AI
    // Procesa cualquier consulta, desde un saludo ("hola") hasta párrafos extensos de texto y código.
    try {
      if (ref != null) {
        ref.read(chatProvider.notifier).send(query);
      } else {
        final container = ProviderScope.containerOf(context, listen: false);
        container.read(chatProvider.notifier).send(query);
      }
    } catch (_) {
      // Fallback seguro si no hay ProviderScope en contexto
    }
    context.go('/chat');
  }

  static bool _isTerminalCommand(String text) {
    const commonCommands = {
      'ls',
      'pwd',
      'cd',
      'top',
      'htop',
      'curl',
      'wget',
      'git',
      'python',
      'bash',
      'sh',
      'kali',
      'apt',
      'dpkg',
      'cat',
      'ping',
      'ssh',
      'grep',
      'find',
      'uname',
      'df',
      'free',
      'whoami',
    };
    final firstWord = text.split(RegExp(r'\s+')).first;
    return commonCommands.contains(firstWord);
  }
}
