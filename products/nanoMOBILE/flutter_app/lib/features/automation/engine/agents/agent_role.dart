/// AgentRole (A13) — roles LÓGICOS de agente.
///
/// NO ejecutan múltiples LLM simultáneos por defecto: comparten el MISMO
/// modelo/runtime. El valor está en la separación de responsabilidades, no en
/// seis modelos en RAM.
library;

enum AgentRole { planner, perception, executor, critic, verifier, memory }
