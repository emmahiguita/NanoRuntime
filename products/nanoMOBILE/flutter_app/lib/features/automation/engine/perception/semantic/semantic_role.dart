/// SemanticRole (A7) — taxonomía semántica de la UI derivada de Accessibility.
///
/// NO es el árbol crudo de Accessibility: es la interpretación semántica.
/// Correctness > coverage: muchos nodos quedarán `unknown` (es honesto).
library;

enum SemanticRole {
  text,
  textField,
  searchField,
  passwordField,

  button,
  iconButton,
  card,

  checkbox,
  switchControl,
  radio,
  slider,

  list,
  listItem,
  grid,

  tab,
  menu,
  menuItem,

  toolbar,
  dialog,

  image,
  link,
  webField,

  keyboard,

  unknown,
}

/// Proveniencia de una clasificación semántica. NUNCA `llm` (el modelo no
/// clasifica la UI; Accessibility lo hace de forma estructurada).
enum SemanticEvidenceSource {
  accessibilityClass,
  accessibilityFlag,
  resourceId,
  textHeuristic,
  structure,
}
