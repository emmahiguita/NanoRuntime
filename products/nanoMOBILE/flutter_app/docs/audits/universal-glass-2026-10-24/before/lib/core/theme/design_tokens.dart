// design_tokens.dart — Sistema universal de tokens de diseño Nano AI.
//
// QUÉ HACE: Centraliza paletas cromáticas, geometría, sombras ópticas, efectos
//   vítreos/metálicos y la extensión de tema [NanoThemeExtension].
// CÓMO FUNCIONA: Arquitectura modular basada en partes (`part / part of`), donde cada
//   archivo contiene menos de 200 líneas con responsabilidad única (SRP - SOLID).
// POR QUÉ: Facilita el mantenimiento, elimina la sobrecarga cognitiva de archivos gigantes,
//   y asegura 100% de compatibilidad con todos los módulos sin romper ninguna importación.
library design_tokens;

import 'package:flutter/material.dart';

part 'nano_colors_contract.part.dart';
part 'nano_dark_colors.part.dart';
part 'nano_light_colors.part.dart';
part 'nano_space_gray_colors.part.dart';
part 'nano_classic_light_colors.part.dart';
part 'nano_system_colors.part.dart';
part 'nano_lerped_colors.part.dart';
part 'nano_geometry_tokens.part.dart';
part 'nano_shadow_tokens.part.dart';
part 'nano_surface_optics.part.dart';
part 'nano_theme_extension.part.dart';
