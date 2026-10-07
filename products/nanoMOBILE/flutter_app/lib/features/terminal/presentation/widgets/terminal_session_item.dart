import 'package:flutter/material.dart';

/// Modelo de datos liviano y desacoplado que representa una sesión activa de terminal.
///
/// QUÉ HACE:
/// Mantiene los metadatos necesarios (ID monotónico, título dinámico, ruta de trabajo,
/// tipo de shell y GlobalKey para comunicarse con el estado POSIX/PTY).
///
/// CÓMO FUNCIONA:
/// Cada pestaña del terminal posee una instancia única de este modelo. Su GlobalKey
/// vincula la barra de pestañas y el dock de entrada con el [NanoTerminalState] real.
///
/// POR QUÉ:
/// Desacopla la lógica de gestión de sesiones de los widgets de presentación,
/// facilitando el mantenimiento y garantizando el principio de responsabilidad única (SRP).
class TerminalSessionItem {
  final int id;
  String name;
  final String cwd;
  final String type;
  final Color? color;
  final GlobalKey key;

  TerminalSessionItem({
    required this.id,
    required this.name,
    required this.cwd,
    required this.type,
    this.color,
    required this.key,
  });

  /// Serialización simple para persistencia local en SharedPreferences.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cwd': cwd,
        'type': type,
      };
}
