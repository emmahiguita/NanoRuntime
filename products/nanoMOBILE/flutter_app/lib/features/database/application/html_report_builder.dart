// QUÉ: genera un reporte HTML autónomo, seguro y legible sin conexión.
// CÓMO: escapa todos los valores y compone CSS adaptable dentro del documento.
// POR QUÉ: el usuario puede visualizar o exportar datos sin abandonar NanoAI.

import '../domain/data_models.dart';

abstract final class HtmlReportBuilder {
  static String build({
    required DataTable table,
    required DataReportConfig config,
  }) {
    String escape(Object? value) => '${value ?? ''}'
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    final rows = table.rows.take(config.maxRows);
    final truncated = table.rowCount > config.maxRows;
    return '''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escape(config.title)}</title><style>
:root{color-scheme:dark}body{margin:0;background:#07111f;color:#e5edf7;font-family:Inter,system-ui,sans-serif}main{padding:28px;max-width:1200px;margin:auto}.hero{background:linear-gradient(135deg,#0f2742,#10223a);border:1px solid #254565;border-radius:20px;padding:24px}h1{margin:4px 0 8px;font-size:28px}.meta{color:#8eb7da}.metrics{display:grid;grid-template-columns:repeat(3,minmax(120px,1fr));gap:12px;margin:18px 0}.card{background:#0e2035;border:1px solid #203f5d;border-radius:14px;padding:16px}.card b{display:block;font-size:24px;color:#5eead4}section{overflow:auto;border:1px solid #203f5d;border-radius:16px}table{border-collapse:collapse;width:100%;min-width:680px}th{position:sticky;top:0;background:#16304b;color:#93c5fd}th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #18334e;font-size:13px}tr:nth-child(even){background:#0b1a2c}.notice{color:#fcd34d;margin:12px 0}@media(max-width:600px){main{padding:14px}.metrics{grid-template-columns:1fr}}
</style></head><body><main><div class="hero"><div class="meta">${escape(config.companyName)}</div><h1>${escape(config.title)}</h1><div>${escape(config.subtitle)}</div></div>
<div class="metrics"><div class="card">Registros<b>${table.rowCount}</b></div><div class="card">Columnas<b>${table.columnCount}</b></div><div class="card">Origen<b>${escape(table.name)}</b></div></div>
${truncated ? '<p class="notice">Vista limitada a ${config.maxRows} de ${table.rowCount} filas. El archivo CSV conserva todos los registros.</p>' : ''}
<section><table><thead><tr>${table.columns.map((c) => '<th>${escape(c)}</th>').join()}</tr></thead><tbody>
${rows.map((row) => '<tr>${List.generate(table.columnCount, (i) => '<td>${escape(i < row.length ? row[i] : '')}</td>').join()}</tr>').join('\n')}
</tbody></table></section></main></body></html>''';
  }
}
