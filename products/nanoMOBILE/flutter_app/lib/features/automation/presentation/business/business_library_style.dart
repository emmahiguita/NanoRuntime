import 'package:flutter/material.dart';

/// Acceso al tema heredado, sin crear otra paleta o ThemeData para la biblioteca.
/// Cada control depende del contexto, por lo que reacciona al cambiar de tema.
extension BusinessLibraryStyle on BuildContext {
  ColorScheme get libraryColors => Theme.of(this).colorScheme;
  bool get libraryIsDark => Theme.of(this).brightness == Brightness.dark;
}
