// QUÉ: define las partes editables de un informe de Data Studio.
// CÓMO: conserva un orden estable que la UI puede reordenar y activar.
// POR QUÉ: dominio, pantalla y PDF comparten el mismo contrato sin duplicados.

/// Secciones disponibles para construir un PDF con datos calculados realmente.
enum ReportSection {
  overview,
  numericStatistics,
  distribution,
  trend,
  quality,
  dataTable,
}

/// Orden profesional inicial; el usuario puede cambiarlo antes de exportar.
const kDefaultReportSections = <ReportSection>[
  ReportSection.overview,
  ReportSection.numericStatistics,
  ReportSection.distribution,
  ReportSection.trend,
  ReportSection.quality,
  ReportSection.dataTable,
];

/// Textos de presentación centralizados para mantener nombres consistentes.
extension ReportSectionMetadata on ReportSection {
  String get title => switch (this) {
    ReportSection.overview => 'Resumen ejecutivo',
    ReportSection.numericStatistics => 'Estadísticas numéricas',
    ReportSection.distribution => 'Distribución por categoría',
    ReportSection.trend => 'Serie y tendencia',
    ReportSection.quality => 'Calidad de datos',
    ReportSection.dataTable => 'Muestra tabular',
  };

  String get description => switch (this) {
    ReportSection.overview => 'Filas, columnas, latencia, consulta y notas',
    ReportSection.numericStatistics => 'Mínimo, máximo, promedio y dispersión',
    ReportSection.distribution =>
      'Frecuencias reales de la categoría principal',
    ReportSection.trend => 'Valores reales ordenados por su etiqueta',
    ReportSection.quality => 'Completitud y faltantes por columna',
    ReportSection.dataTable => 'Registros reales paginados y organizados',
  };
}
