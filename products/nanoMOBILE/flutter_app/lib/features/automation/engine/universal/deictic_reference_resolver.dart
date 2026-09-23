/// QUÉ HACE:
/// Resuelve referencias anafóricas y deícticas en instrucciones del usuario
/// («ese Excel», «el archivo», «la tabla», «ese producto», «el anterior»).
///
/// CÓMO FUNCIONA:
/// Inspecciona la memoria de corto plazo, el último archivo manipulado en Linux/Terminal,
/// las tablas recientes de Data Studio y el producto activo de la conversación comercial.
///
/// POR QUÉ:
/// Las personas dan órdenes con referencias implícitas al contexto reciente; si el agente
/// no las ancla a un recurso real, alucina nombres de archivo o pide aclaraciones innecesarias.
library;

import '../business/fact_selector.dart' show normalizeText;
import 'universal_instruction_contract.dart';

final class DeicticReferenceResolver {
  const DeicticReferenceResolver();

  static const _spreadsheetTokens = [
    'ese excel', 'el excel', 'este excel', 'aquel excel',
    'la planilla', 'esa planilla', 'el archivo excel', 'la hoja de calculo',
    'el csv', 'ese csv',
  ];

  static const _fileTokens = [
    'ese archivo', 'el archivo', 'este archivo', 'el documento', 'ese doc',
  ];

  static const _tableTokens = [
    'la tabla', 'esa tabla', 'la base de datos', 'el reporte', 'ese reporte',
  ];

  static const _productTokens = [
    'ese producto', 'el producto', 'ese telefono', 'el telefono',
    'ese articulo', 'la negra', 'el negro', 'el que te dije', 'el anterior',
  ];

  /// Extrae y resuelve las referencias deícticas presentes en el texto del usuario.
  List<DeicticReference> resolve({
    required String text,
    String? lastLinuxFilePath,
    String? recentTableOrReportPath,
    String? activeProductContext,
  }) {
    final norm = normalizeText(text);
    final results = <DeicticReference>[];

    // 1. Detección de Excel / Hoja de cálculo / CSV
    for (final token in _spreadsheetTokens) {
      if (norm.contains(token)) {
        final resolved = _resolveSpreadsheet(
          lastLinuxFilePath: lastLinuxFilePath,
          recentTablePath: recentTableOrReportPath,
        );
        results.add(DeicticReference(
          phrase: token,
          category: 'file',
          resolvedValue: resolved,
        ));
        break;
      }
    }

    // 2. Detección genérica de archivo
    if (results.isEmpty) {
      for (final token in _fileTokens) {
        if (norm.contains(token)) {
          final resolved = lastLinuxFilePath ?? recentTableOrReportPath;
          results.add(DeicticReference(
            phrase: token,
            category: 'file',
            resolvedValue: resolved,
          ));
          break;
        }
      }
    }

    // 3. Detección de tablas o reportes de datos
    for (final token in _tableTokens) {
      if (norm.contains(token)) {
        results.add(DeicticReference(
          phrase: token,
          category: 'table',
          resolvedValue: recentTableOrReportPath,
        ));
        break;
      }
    }

    // 4. Detección de productos o artículos comerciales
    for (final token in _productTokens) {
      if (norm.contains(token)) {
        results.add(DeicticReference(
          phrase: token,
          category: 'product',
          resolvedValue: activeProductContext,
        ));
        break;
      }
    }

    return results;
  }

  static String? _resolveSpreadsheet({
    String? lastLinuxFilePath,
    String? recentTablePath,
  }) {
    if (lastLinuxFilePath != null && _isSpreadsheet(lastLinuxFilePath)) {
      return lastLinuxFilePath;
    }
    if (recentTablePath != null && _isSpreadsheet(recentTablePath)) {
      return recentTablePath;
    }
    // Fallback: si hay un archivo reciente cualquiera en Linux, asociarlo
    if (lastLinuxFilePath != null && lastLinuxFilePath.isNotEmpty) {
      return lastLinuxFilePath;
    }
    return recentTablePath;
  }

  static bool _isSpreadsheet(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.tsv');
  }
}
