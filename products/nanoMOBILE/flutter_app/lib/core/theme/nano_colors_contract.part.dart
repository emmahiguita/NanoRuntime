part of 'design_tokens.dart';

/// Interfaz semántica de colores del ecosistema Nano AI.
///
/// - QUÉ HACE: Define el contrato abstracto universal de colores para toda la aplicación móvil.
/// - CÓMO FUNCIONA: Expone getters inmutables agrupados por jerarquía: marca, contenedores,
///   superficies, bordes, estados funcionales, cristales ópticos y acentos cromáticos.
/// - POR QUÉ: Aplica los principios SOLID de Inversión de Dependencias (DIP) y Segregación
///   de Interfaces (ISP). Los widgets consumen [NanoColors] sin acoplarse a implementaciones
///   concretas de modo claro, oscuro u opaco.
abstract class NanoColors {
  // --- Roles Principales y Contenedores Semánticos ---
  Color get primary;
  Color get primaryContainer;
  Color get onPrimaryContainer;
  Color get secondary;
  Color get secondaryContainer;
  Color get surface;
  Color get surfaceVariant;
  Color get background;
  Color get onSurface;
  Color get onSurfaceVariant;
  Color get outline;
  Color get outlineVariant;
  Color get tertiary;

  // --- Estados Funcionales (Feedback de Sistema) ---
  Color get success;
  Color get warning;
  Color get error;
  Color get info;

  // --- Roles Especializados de Interfaz y Chat ---
  Color get accent; // Color de resalte y foco principal
  Color get onAccent; // Texto/icono sobre superficies de acento
  Color get danger; // Estado crítico o acción destructiva
  Color get codeBlockBg; // Fondo de bloques de sintaxis markdown
  Color get quoteBg; // Fondo de citas y blockquotes
  Color get terminalBg; // Fondo de terminal interactiva
  Color get terminalGreen; // Verde de salida o acento de consola

  // --- Tokens de Glassmorphism (Efecto Cristal Óptico) ---
  Color get glassSurface;
  Color get glassBorder;
  Color get glassOverlay;

  // --- Gradientes Metálicos y Reflectivos ---
  Color get bgTop;
  Color get bgMiddle;
  Color get bgBottom;

  Color get glass100;
  Color get glass200;
  Color get glass300;
  Color get glass400;

  Color get metalWhite;
  Color get metalPearl;
  Color get metalSilver;
  Color get metalCool;
  Color get metalSteel;
  Color get metalGraphite;
  Color get metalDark;

  Color get warmReflect1;
  Color get warmReflect2;
  Color get warmReflect3;

  Color get coldReflect1;
  Color get coldReflect2;
  Color get coldReflect3;
  Color get coldReflect4;
  Color get coldReflect5;

  Color get nanoCyan;
  Color get nanoTurquoise;
  Color get nanoBlue;
  Color get nanoViolet;

  // --- Capas Semánticas de Elevación y Fondos ---
  Color get backgroundPrimary;
  Color get backgroundSecondary;
  Color get backgroundElevated;
  Color get backgroundIce;
  Color get backgroundPearl;
  Color get backgroundDeep;
  Color get backgroundNavy;

  Color get glassPrimary;
  Color get glassSecondary;
  Color get glassGraphite;
  Color get glassBlue;

  // --- Factores de Opacidad Óptica ---
  double get glassLow;
  double get glassMedium;
  double get glassStrong;
  double get glassOpaque;

  // --- Tipografía y Jerarquía Textual ---
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get textDisabled;

  // --- Acentos de Color Harmonizados ---
  Color get accentCyan;
  Color get accentMint;
  Color get accentSky;
  Color get accentBlue;
  Color get accentLavender;

  // --- Refracciones y Reflejos Especulares ---
  Color get iceReflection;
  Color get silverReflection;
  Color get pearlReflection;
  Color get warmReflection;
  Color get lavenderReflection;

  // --- Bordes Perimetrales y Estructurales ---
  Color get borderPrimaryColor;
  Color get borderSecondaryColor;
  Color get borderAccentColor;

  /// Marca la identidad "Clásico" (true para modo clásico, false para estándar).
  bool get isClassicOrange => false;
}
