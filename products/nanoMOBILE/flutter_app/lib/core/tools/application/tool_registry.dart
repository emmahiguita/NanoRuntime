/// Bootstrap-safe registry for formal capabilities.
library;

import '../domain/executable_tool.dart';

abstract interface class IToolRegistry {
  void register(RegisteredTool tool);
  RegisteredTool? resolve(String toolId, {int? version});
  List<RegisteredTool> list({bool includeDisabled = false});
  void enable(String toolId, {int? version});
  void disable(String toolId, {int? version});
  void freeze();
  bool get isFrozen;
}

final class ToolRegistry implements IToolRegistry {
  final Map<String, RegisteredTool> _tools = {};
  final Set<String> _disabled = {};
  bool _frozen = false;

  String _key(String id, int version) => '${id.toLowerCase()}@$version';

  @override
  void register(RegisteredTool tool) {
    if (_frozen) {
      throw StateError('El ToolRegistry está congelado; bootstrap ya terminó.');
    }
    final definition = tool.definition;
    final key = _key(definition.id, definition.version);
    if (_tools.containsKey(key)) {
      throw StateError('Tool ID duplicado: ${definition.versionedId}.');
    }
    _tools[key] = tool;
  }

  @override
  RegisteredTool? resolve(String toolId, {int? version}) {
    if (version != null) {
      final key = _key(toolId, version);
      if (_disabled.contains(key)) return null;
      return _tools[key];
    }
    final prefix = '${toolId.toLowerCase()}@';
    final matches =
        _tools.entries
            .where(
              (entry) =>
                  entry.key.startsWith(prefix) &&
                  !_disabled.contains(entry.key),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => right.value.definition.version.compareTo(
              left.value.definition.version,
            ),
          );
    return matches.isEmpty ? null : matches.first.value;
  }

  @override
  List<RegisteredTool> list({bool includeDisabled = false}) {
    final values =
        _tools.entries
            .where((entry) => includeDisabled || !_disabled.contains(entry.key))
            .map((entry) => entry.value)
            .toList(growable: false)
          ..sort(
            (left, right) => left.definition.versionedId.compareTo(
              right.definition.versionedId,
            ),
          );
    return List.unmodifiable(values);
  }

  @override
  void enable(String toolId, {int? version}) {
    final tool = _resolveIncludingDisabled(toolId, version: version);
    if (tool == null) throw StateError('Tool no registrada: $toolId.');
    _disabled.remove(_key(tool.definition.id, tool.definition.version));
  }

  @override
  void disable(String toolId, {int? version}) {
    final tool = _resolveIncludingDisabled(toolId, version: version);
    if (tool == null) throw StateError('Tool no registrada: $toolId.');
    _disabled.add(_key(tool.definition.id, tool.definition.version));
  }

  RegisteredTool? _resolveIncludingDisabled(String toolId, {int? version}) {
    if (version != null) return _tools[_key(toolId, version)];
    final prefix = '${toolId.toLowerCase()}@';
    final matches =
        _tools.entries
            .where((entry) => entry.key.startsWith(prefix))
            .map((entry) => entry.value)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                right.definition.version.compareTo(left.definition.version),
          );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void freeze() => _frozen = true;

  @override
  bool get isFrozen => _frozen;
}
