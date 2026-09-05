import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Despachador inteligente de comandos y búsquedas universales de Nano AI.
///
/// Aplica el principio de Responsabilidad Única (SRP) para analizar
/// intenciones de texto introducidas en la barra cósmica y enrutar
/// al destino adecuado (Terminal, Automatización, Modelos, Ajustes o Chat).
class NanoSearchDispatcher {
  const NanoSearchDispatcher._();

  static void dispatch(BuildContext context, String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final lower = query.toLowerCase();

    // 1. Detección de comandos de consola/terminal
    if (query.startsWith('/') ||
        query.startsWith('>') ||
        query.startsWith('\$') ||
        _isTerminalCommand(lower)) {
      final cleanCmd = query.replaceFirst(RegExp(r'^[/ >\$]+'), '').trim();
      context.push('/terminal/shell?cmd=${Uri.encodeComponent(cleanCmd.isEmpty ? query : cleanCmd)}');
      return;
    }

    // 2. Detección de intenciones de automatización
    if (lower.contains('automatiz') ||
        lower.contains('regla') ||
        lower.contains('tarea') ||
        lower.contains('trigger') ||
        lower.contains('notific') ||
        lower.contains('ejecut')) {
      context.push('/automation');
      return;
    }

    // 3. Detección de modelos de IA
    if (lower.contains('modelo') ||
        lower.contains('llm') ||
        lower.contains('deepseek') ||
        lower.contains('descargar') ||
        lower.contains('pesos')) {
      context.go('/models');
      return;
    }

    // 4. Detección de ajustes y configuración
    if (lower.contains('ajuste') ||
        lower.contains('config') ||
        lower.contains('tema') ||
        lower.contains('color') ||
        lower.contains('preferenc')) {
      context.go('/settings');
      return;
    }

    // 5. Por defecto: conversación inteligente en el Chat de Nano AI
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
    };
    final firstWord = text.split(RegExp(r'\s+')).first;
    return commonCommands.contains(firstWord);
  }
}
