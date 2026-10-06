/// Skill de instrucciones importada por la persona; no contiene código ejecutable.
library;

class PromptSkill {
  const PromptSkill({
    required this.name,
    required this.description,
    required this.instructions,
    required this.source,
    required this.installedAt,
  });

  final String name;
  final String description;
  final String instructions;
  final String source;
  final DateTime installedAt;

  /// Acepta el subconjunto estándar name/description + cuerpo Markdown de SKILL.md.
  factory PromptSkill.parse(String markdown, {String source = 'pegado'}) {
    if (markdown.length > 24000) throw const FormatException('skill_too_large');
    final lines = markdown.replaceAll('\r', '').split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      throw const FormatException('missing_skill_frontmatter');
    }
    final end = lines.indexOf('---', 1);
    if (end < 0) throw const FormatException('invalid_skill_frontmatter');
    final fields = <String, String>{};
    for (final line in lines.skip(1).take(end - 1)) {
      final match = RegExp(r'^([a-z-]+):\s*(.*)$').firstMatch(line.trim());
      if (match != null) fields[match.group(1)!] = _unquote(match.group(2)!);
    }
    final name = (fields['name'] ?? '').trim().toLowerCase();
    final description = (fields['description'] ?? '').trim();
    final instructions = lines.skip(end + 1).join('\n').trim();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(name) ||
        description.isEmpty ||
        description.length > 500 ||
        instructions.isEmpty) {
      throw const FormatException('invalid_skill_metadata');
    }
    return PromptSkill(
      name: name,
      description: description,
      instructions: instructions,
      source: source,
      installedAt: DateTime.now().toUtc(),
    );
  }

  static String _unquote(String value) {
    final clean = value.trim();
    if (clean.length >= 2 &&
        ((clean.startsWith('"') && clean.endsWith('"')) ||
            (clean.startsWith("'") && clean.endsWith("'")))) {
      return clean.substring(1, clean.length - 1);
    }
    return clean;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'instructions': instructions,
    'source': source,
    'installedAt': installedAt.toIso8601String(),
  };

  factory PromptSkill.fromJson(Map<String, dynamic> json) => PromptSkill(
    name: json['name'] as String,
    description: json['description'] as String,
    instructions: json['instructions'] as String,
    source: json['source'] as String? ?? 'importado',
    installedAt:
        DateTime.tryParse(json['installedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
