# Codex para desarrollar Nano

Configuración realizada el 26 de octubre de 2026. Alcance: herramientas y
procedimientos de desarrollo de Codex sobre este repositorio.

## Instalado

| Recurso | Procedencia | Uso |
| --- | --- | --- |
| `flutter-fix-layout-issues` | Flutter | Diagnosticar constraints y desbordamientos. |
| `flutter-build-responsive-layout` | Flutter | Adaptar componentes al espacio disponible. |
| `dart-write-documentation` | Dart | Documentar responsabilidades y contratos. |
| `nano-development-workflow` | Proyecto | Conectar diagnóstico, corrección y evidencia. |

Las tres guías externas se descargaron con el instalador de skills de Codex,
después de revisar sus instrucciones. Se guardaron en `.agents/skills`, con
alcance de repositorio. `skills-inventory.json` registra archivos, origen y
huellas SHA-256 para identificar esta instalación.

Fuentes:
- https://github.com/flutter/agent-plugins/tree/main/skills
- https://github.com/dart-lang/skills/tree/main/skills
- https://learn.chatgpt.com/docs/build-skills
- https://learn.chatgpt.com/docs/agent-configuration/agents-md

## MCP Dart y Flutter

`.codex/config.toml` utiliza el SDK de Flutter ya instalado en
`C:/src/flutter/flutter`. No descarga otro servidor ni necesita claves API.
Las rutas son propias de este equipo; hay que ajustarlas si cambia el SDK.

Se habilitan únicamente registro de raíces, consulta de paquetes, conexión al
daemon y lecturas de diagnóstico. La lista excluye ejecución de pruebas,
Flutter Driver, lanzamiento de apps, hot reload, cambios de dependencias y
correcciones o formato automáticos. Estas restricciones son de este servidor;
no sustituyen las instrucciones del usuario para otras herramientas.

La inspección de protocolo inicializó el servidor `dart and flutter tooling`
versión `0.1.1`, registró la raíz real del paquete y leyó las herramientas
disponibles. El proceso temporal se cerró después de la inspección.
Evidencia: `dart-mcp-inspection.json`. No se ejecutó Nano ni una suite de pruebas.

Esta versión no anunció `analyze_files` en la inspección. Se conserva `dart
analyze` como alternativa para análisis estático. Leer errores o widgets exige
una app en depuración conectada a un URI DTD real; instalar el MCP no crea esa
sesión ni da acceso al estado de un APK de producción.

Configuración basada en:
https://learn.chatgpt.com/docs/extend/mcp?surface=cli

## Reutilización

Se conservan los MCP existentes de grafo de código y ARTEMIS, así como las skills
de cristal, microinteracciones, transiciones y rendimiento ya instaladas.
No se duplican con un segundo sistema de instrucciones de animación.

El grafo descubre dependencias; las skills guían cambios; el MCP Dart consulta
el entorno de desarrollo. ARTEMIS queda para revisiones del teléfono que el
usuario solicite. Ninguno acredita por sí solo un envío o una mejora de rendimiento.

Los hooks existentes permanecen como estaban. El ciclo de mejora es un flujo
de instrucciones dentro de la tarea, con revisión de evidencia tras cada cambio;
no se instaló un hook que repita acciones, ejecute pruebas o mantenga procesos
en segundo plano. Tampoco se añadieron Context7, Playwright o browser-use: no
son necesarios para el alcance actual de Nano Android y ya hay consulta de
fuentes y herramientas de dispositivo disponibles.

## Uso

1. Abre el proyecto en Codex. Las nuevas skills estarán disponibles en el
   siguiente turno; también puedes invocar `$nano-development-workflow`.
2. Reinicia Codex o recarga sus servidores MCP para cargar `dart_flutter`.
   La configuración local se carga solo si Codex considera confiable el proyecto.
3. Pide una corrección concreta y el nivel de verificación permitido. Se mantiene
   el acuerdo actual de no ejecutar pruebas.
4. Para diagnóstico conectado, proporciona o recupera el URI DTD real de la
   sesión de desarrollo autorizada. No pegues claves ni tokens en informes.

Estado: instalación de skills y sintaxis de configuración comprobadas; protocolo
del servidor inspeccionado. La carga del nuevo MCP dentro de una sesión nueva
de Codex queda pendiente de esa recarga. No se cambió, compiló ni instaló la app.
