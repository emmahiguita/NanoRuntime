# A14 — MCP / Shizuku adapters (tipados, opcionales)

> Estado: DOMAIN COMPLETE · BACKENDS NOT DEVICE-READY (sin servidor MCP ni
> Shizuku en el repo) · NO WIRED.

## MCP

`McpTool { id, name, category }` + `McpToolCategory { read, device,
externalWrite, privileged }`. `McpToolAdapter` convierte una MCP tool → 
CandidateAction grounded (channel `mcp`, tool categórico `mcp.<category>` que
el firewall A11 mapea a un ActionEffect). La tool MCP NUNCA llega a ejecución
sin pasar por governance (firewall/critic/broker). Sin LLM → MCP → shell.

## Shizuku

`ShizukuCapability { installPackage, forceStopPackage, grantSpecificPermission,
queryPackage }`. `ShizukuCapabilityProvider` genera CandidateAction tipados
(channel `shizuku`, capability `shizuku`). NUNCA `executeShell(String)`: solo
capacidades tipadas con schema/risk/policy/verification. El PrivilegeBroker las
marca `shizuku` tier → unavailable hasta que el backend exista.

## Governance integration

`effectOfTool` extendido para tools MCP (`mcp.read/device/externalWrite/
privileged`) y Shizuku (`install_package` → installPackage, etc.). El pipeline
A11 (firewall → critic → broker) deniega capabilities privilegiadas no
disponibles. Shizuku/privileged → `GovernanceDenied` (unavailable).

## Seguridad

Sin shell arbitrario, sin ADB/root en A14, sin elevación de privilegios. MCP y
Shizuku entran como fuentes de capacidades tipadas, no como bypass. El
contenido de pantalla/OCR/Vision no puede activar MCP/Shizuku.

## Estado de backends

MCP server y Shizuku son futuros (DOMAIN COMPLETE, BACKENDS NOT DEVICE-READY).
A14 define los contratos + integración governance para que cuando el backend
exista, nazca obligado a pasar por governance.

## Limitaciones

- Sin backend MCP real ni Shizuku.
- privileged category mapea a `shizuku` (deviceOwner/root futuros).
- Sin verify específica por capability (postcondición delegada al backend).

## A15 seam

Voz + benchmark físico + optimización. A14 cierra la extensión de capacidades
privilegiadas (tipadas) sin romper el corazón del sistema.
