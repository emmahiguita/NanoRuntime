import 'package:nanoai/core/tools/domain/executable_tool.dart';
import 'package:nanoai/core/tools/domain/tool_definition.dart';
import 'package:nanoai/core/tools/domain/tool_input.dart';
import 'package:nanoai/core/tools/domain/tool_permission.dart';
import 'package:nanoai/core/tools/domain/tool_result.dart';
import 'package:nanoai/core/tools/domain/tool_risk.dart';
import 'package:nanoai/core/tools/infrastructure/action_tool_adapter.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_style_constraints.dart';

final class GetPersonalStyleArguments implements ToolArguments {
  const GetPersonalStyleArguments();
  factory GetPersonalStyleArguments.fromMap(Map<String, dynamic> _) =>
      const GetPersonalStyleArguments();

  @override
  Map<String, Object?> toRedactedMap() => const {};
}

final class PersonalStyleSnapshot {
  const PersonalStyleSnapshot({
    required this.maxTypicalSentences,
    required this.preferredAnswerLength,
    required this.preferredReciprocity,
    required this.preferredExpressions,
    required this.avoidExpressions,
  });

  final int maxTypicalSentences;
  final String preferredAnswerLength;
  final bool preferredReciprocity;
  final List<String> preferredExpressions;
  final List<String> avoidExpressions;
}

final class FindPersonalExamplesArguments implements ToolArguments {
  const FindPersonalExamplesArguments({required this.query, this.limit = 3});

  factory FindPersonalExamplesArguments.fromMap(Map<String, dynamic> raw) {
    final query = '${raw['query'] ?? ''}'.trim();
    if (query.isEmpty) throw const FormatException('query es obligatorio.');
    final limit = (raw['limit'] as num?)?.toInt() ?? 3;
    return FindPersonalExamplesArguments(
      query: query,
      limit: limit.clamp(1, 10),
    );
  }

  final String query;
  final int limit;

  @override
  Map<String, Object?> toRedactedMap() => {
    'queryLength': query.length,
    'limit': limit,
  };
}

abstract final class PersonalActions {
  static RegisteredTool createGetStyleTool({
    PersonalStyleConstraints? constraints,
  }) {
    final active = constraints ?? PersonalStyleConstraints.defaultEmmanuel;
    final tool =
        ActionToolAdapter<GetPersonalStyleArguments, PersonalStyleSnapshot>(
          definition: const ToolDefinition(
            id: 'personal.getStyle',
            version: 1,
            displayName: 'Obtener estilo personal',
            description: 'Lee las restricciones conversacionales del dueño.',
            category: ToolCategory.domainAction,
            risk: ToolRiskLevel.readOnly,
            sideEffect: ToolSideEffect.localRead,
            requiredPermissions: [ToolPermission.memoryRead],
            allowedRoles: [AgentCallerRole.personal, AgentCallerRole.system],
            allowedExecutionModes: [
              ToolExecutionMode.foreground,
              ToolExecutionMode.background,
              ToolExecutionMode.headless,
            ],
            outputSchema: {'type': 'PersonalStyleSnapshot'},
            tags: {'personal', 'style', 'read'},
          ),
          onExecute: (context) async => ToolResult.success(
            output: PersonalStyleSnapshot(
              maxTypicalSentences: active.maxTypicalSentences,
              preferredAnswerLength: active.preferredAnswerLength,
              preferredReciprocity: active.preferredReciprocity,
              preferredExpressions: active.preferredExpressions,
              avoidExpressions: active.avoidExpressions,
            ),
            executionId: context.executionId,
          ),
        );
    return TypedToolRegistration(
      tool: tool,
      decoder: GetPersonalStyleArguments.fromMap,
    );
  }

  static RegisteredTool createFindExamplesTool({
    PersonaRepository? repository,
  }) {
    final tool = ActionToolAdapter<FindPersonalExamplesArguments, List<Object?>>(
      definition: const ToolDefinition(
        id: 'personal.findExamples',
        version: 1,
        displayName: 'Buscar ejemplos de estilo',
        description:
            'Busca pares conversacionales en el repositorio FTS4 existente.',
        category: ToolCategory.domainAction,
        risk: ToolRiskLevel.readOnly,
        sideEffect: ToolSideEffect.localRead,
        requiredPermissions: [ToolPermission.memoryRead],
        allowedRoles: [AgentCallerRole.personal, AgentCallerRole.system],
        allowedExecutionModes: [
          ToolExecutionMode.foreground,
          ToolExecutionMode.background,
          ToolExecutionMode.headless,
        ],
        inputSchema: {
          'required': ['query'],
          'properties': {'query': 'string', 'limit': 'integer'},
        },
        outputSchema: {'type': 'List<PersonaExample>'},
        tags: {'personal', 'memory', 'fts4', 'read'},
      ),
      onExecute: (context) async {
        final startedAt = DateTime.now();
        final arguments = context.arguments;
        final examples = await (repository ?? PersonaRepository.instance)
            .searchExamples(arguments.query, limit: arguments.limit);
        return ToolResult.success(
          output: List<Object?>.unmodifiable(examples),
          startedAt: startedAt,
          executionId: context.executionId,
          evidence: [
            ToolEvidence(
              type: ToolEvidenceType.databaseRecordFound,
              source: 'persona_repository',
              timestamp: DateTime.now(),
              data: {'matchedCount': examples.length},
            ),
          ],
        );
      },
    );
    return TypedToolRegistration(
      tool: tool,
      decoder: FindPersonalExamplesArguments.fromMap,
    );
  }
}
