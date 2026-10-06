// QUÉ: identifica las tres vistas reales disponibles en el navegador.
// CÓMO: se comparte entre el coordinador, la barra y el selector visual.
// POR QUÉ: evita valores de texto duplicados y acciones de vista ambiguas.

enum BrowserDisplayMode { focused, verticalStack, carousel3D }
