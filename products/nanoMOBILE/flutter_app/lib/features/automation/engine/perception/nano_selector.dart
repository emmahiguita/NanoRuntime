/// Selector compuesto para el árbol de accesibilidad + mini-DSL de texto.
///
/// Inspirado en Playwright Locators: criterios semánticos (role, texto, id,
/// package) en vez de XPath estructural o coordenadas. El [NanoSelectorEngine]
/// puntúa cada nodo contra estos criterios; dos nodos con puntuación pareja
/// dan AMBIGUOUS_TARGET y no se toca nada.
library;

/// Cómo se compara el texto/descripción contra el nodo.
enum TextMatcher { exact, contains, regex }

/// Rol semántico derivado del className Android (mapeo en [RoleDerivation]).
enum Role {
  button,
  editText,
  textView,
  imageView,
  checkBox,
  switch_,
  listItem,
  other,
}

/// Derivación de rol desde className. Mapeo conservador: los widgets más
/// comunes de android.widget / android.view; todo lo demás cae en [Role.other]
/// (sin penalización — solo no aporta el bonus role+texto).
abstract final class RoleDerivation {
  static Role fromClassName(String className) {
    final short = className.substring(className.lastIndexOf('.') + 1);
    return switch (short) {
      'Button' || 'ImageButton' || 'MaterialButton' => Role.button,
      'EditText' ||
      'AutoCompleteTextView' ||
      'MultiAutoCompleteTextView' => Role.editText,
      'TextView' => Role.textView,
      'ImageView' => Role.imageView,
      'CheckBox' => Role.checkBox,
      'Switch' || 'SwitchCompat' || 'ToggleButton' => Role.switch_,
      'ListView' || 'RecyclerView' || 'GridView' => Role.listItem,
      _ => Role.other,
    };
  }
}

/// Selector compuesto. Todos los campos opcionales, pero al menos un criterio
/// (se valida en el constructor). [expectedCount] controla cuántos nodos se
/// esperan sin ambigüedad (default 1).
class NanoSelector {
  final String? packageName;
  final String? resourceId;
  final Role? role;
  final String? text;
  final TextMatcher textMatcher;
  final String? description;
  final bool? editable;
  final bool? clickable;

  /// Relación de vecindad: el candidato gana +50 si está geométricamente
  /// junto a un nodo que resuelve este sub-selector (patrón label→campo:
  /// `editable=true, near: desc=Usuario`).
  final NanoSelector? near;

  final int expectedCount;

  const NanoSelector({
    this.packageName,
    this.resourceId,
    this.role,
    this.text,
    this.textMatcher = TextMatcher.exact,
    this.description,
    this.editable,
    this.clickable,
    this.near,
    this.expectedCount = 1,
  }) : assert(expectedCount >= 1, 'expectedCount debe ser >= 1');

  /// Exige al menos un criterio de búsqueda (packageName no cuenta: solo
  /// restringe, no identifica).
  bool get hasAnyCriterion =>
      resourceId != null ||
      role != null ||
      (text != null && text!.isNotEmpty) ||
      (description != null && description!.isNotEmpty) ||
      editable != null ||
      clickable != null ||
      near != null;

  bool get isPackageConstrained =>
      packageName != null && packageName!.isNotEmpty;

  /// Valida el selector: lanza [SelectorFormatException] si no hay criterios,
  /// regex inválido, o expectedCount < 1.
  void validate() {
    if (!hasAnyCriterion) {
      throw const SelectorFormatException(
        'Selector sin criterios: indica al menos text, desc, id, role, '
        'editable o clickable.',
      );
    }
    if (textMatcher == TextMatcher.regex) {
      final source = text ?? description;
      if (source != null) {
        try {
          RegExp(source);
        } catch (e) {
          throw SelectorFormatException('Regex inválido "$source": $e');
        }
      }
    }
    near?.validate();
  }

  /// Mini-DSL para el campo de texto de Settings:
  ///
  ///   `Ajustes`                          → text exact
  ///   `text=Buscar`                      → text exact (explícito)
  ///   `text~=buscar`                     → text contains
  ///   `text/=h[ae]la`                    → text regex
  ///   `desc=Contraseña`                  → description exact
  ///   `id=com.android:id/button1`        → resourceId exact
  ///   `role=button;text=ok`              → rol + texto
  ///   `pkg=com.android.settings;text=WiFi` → restricción de package
  ///   `editable=true;near=desc=Usuario`  → 1er campo junto al label "Usuario"
  ///
  /// Lanza [SelectorFormatException] con motivo legible si la expresión es
  /// inválida o queda sin criterios.
  factory NanoSelector.parse(String expr) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) {
      throw const SelectorFormatException('Expresión vacía.');
    }
    String? pkg;
    String? id;
    Role? role;
    String? text;
    var textMatcher = TextMatcher.exact;
    String? desc;
    bool? editable;
    bool? clickable;
    NanoSelector? near;

    // Sin separadores `=` ni `;` → text exact simple.
    if (!trimmed.contains('=') && !trimmed.contains(';')) {
      text = trimmed;
    } else {
      for (final part in trimmed.split(';')) {
        final p = part.trim();
        if (p.isEmpty) continue;
        final eq = p.indexOf('=');
        // El char inmediatamente anterior al '=' marca el operador (~=, /=).
        final hasOp = eq >= 1 && (p[eq - 1] == '~' || p[eq - 1] == '/');
        final key = hasOp
            ? p.substring(0, eq - 1).trim()
            : p.substring(0, eq).trim();
        final value = eq >= 0 ? p.substring(eq + 1).trim() : '';
        switch (key) {
          case 'pkg':
            pkg = value;
          case 'id':
            id = value;
          case 'role':
            role = switch (value.toLowerCase()) {
              'button' => Role.button,
              'edittext' || 'editable' => Role.editText,
              'textview' => Role.textView,
              'imageview' => Role.imageView,
              'checkbox' => Role.checkBox,
              'switch' => Role.switch_,
              'listitem' => Role.listItem,
              _ => throw SelectorFormatException(
                'Rol desconocido "$value". Válidos: button, editText, '
                'textView, imageView, checkBox, switch, listItem.',
              ),
            };
          case 'text':
            text = value;
          case 'desc':
            desc = value;
          case 'editable':
            editable = switch (value.toLowerCase()) {
              'true' || '1' => true,
              'false' || '0' => false,
              _ => throw SelectorFormatException(
                'editable espera true/false, no "$value".',
              ),
            };
          case 'clickable':
            clickable = switch (value.toLowerCase()) {
              'true' || '1' => true,
              'false' || '0' => false,
              _ => throw SelectorFormatException(
                'clickable espera true/false, no "$value".',
              ),
            };
          case 'near':
            near = NanoSelector.parse(value);
          default:
            throw SelectorFormatException(
              'Clave desconocida "$key" en "$part". Válidas: pkg, id, role, '
              'text, desc, editable, clickable, near.',
            );
        }
        if (hasOp) {
          if (key != 'text' && key != 'desc') {
            throw SelectorFormatException(
              'Operador "${p[eq - 1]}=" solo aplica a text o desc.',
            );
          }
          textMatcher = p[eq - 1] == '~'
              ? TextMatcher.contains
              : TextMatcher.regex;
        }
      }
    }

    final selector = NanoSelector(
      packageName: pkg,
      resourceId: id,
      role: role,
      text: text,
      textMatcher: textMatcher,
      description: desc,
      editable: editable,
      clickable: clickable,
      near: near,
    );
    selector.validate();
    return selector;
  }

  /// Descripción legible para reportes y feedback de UI.
  String toDebugString() {
    final parts = <String>[
      if (isPackageConstrained) 'pkg=$packageName',
      if (resourceId != null) 'id=$resourceId',
      if (role != null) 'role=${role!.name}',
      if (text != null) 'text=$text',
      if (description != null) 'desc=$description',
      if (editable != null) 'editable=$editable',
      if (clickable != null) 'clickable=$clickable',
      if (near != null) 'near=${near!.toDebugString()}',
    ];
    return parts.join(';');
  }
}

/// Excepción de selector inválido (fail-fast en parse/construcción).
class SelectorFormatException implements Exception {
  final String message;
  const SelectorFormatException(this.message);

  @override
  String toString() => 'SelectorFormatException: $message';
}
