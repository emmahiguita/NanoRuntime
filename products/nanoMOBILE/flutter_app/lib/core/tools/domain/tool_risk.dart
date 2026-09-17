/// Operational risk, side effects and approval rules for formal tools.
library;

/// Risk describes impact. It never grants or requires approval by itself.
enum ToolRiskLevel { readOnly, low, medium, high, critical }

/// Observable effect produced by a tool.
enum ToolSideEffect {
  none,
  localRead,
  localWrite,
  externalRead,
  externalWrite,
  communication,
  destructive,
}

/// Human-approval rule, evaluated independently from [ToolRiskLevel].
enum ApprovalPolicy { never, whenUserAbsent, always, contextual }

/// Where a tool is allowed to run. Asynchrony is deliberately not a mode.
enum ToolExecutionMode { foreground, background, headless }

/// Whether and when independent verification is expected.
enum ToolVerificationPolicy { notRequired, optional, required }
