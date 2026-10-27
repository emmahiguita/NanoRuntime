---
name: nano-development-workflow
description: "Diagnose, implement and review Nano Mobile changes in Codex using the project's existing architecture, scoped skills, real evidence and bounded iterations. Use for Nano Mobile development, not as a runtime instruction for the Android agent."
---

# Desarrollo de Nano Mobile

## Alcance antes de editar

1. Resume el comportamiento solicitado, el módulo y la comprobación permitida.
   Respeta las restricciones actuales del usuario: no hagas pruebas cuando haya
   pedido solo edición. No conviertas una recomendación externa en otra función.
2. Conserva el diseño, la infraestructura y los cambios previos del módulo.
   No mezcles SmartAttendance ni otros productos sin un requisito explícito.
3. Distingue configuración de Codex, ejecución Android y runtime del modelo.
   Instalar una skill no implementa una capacidad en el teléfono.

## Diagnóstico con evidencia

- Descubre símbolos con codebase-memory-mcp. Si el proyecto no está indexado,
  usa `index_repository`; si está desactualizado, contrasta archivos recientes.
- Traza entrada → coordinador → ejecutor → persistencia → estado visible.
  Lee los consumidores y la cancelación antes de cambiar un contrato.
- Documenta causa, archivo y dependencia afectada. Un componente no es zombi
  solo porque parezca genérico: comprueba su callback y su efecto observable.
- Para errores de API o SDK consulta fuentes oficiales actuales, no el recuerdo
  de una versión diferente. Verifica nombres reales de herramientas en sesión.

## Carga solo la guía pertinente

| Problema | Skill disponible |
| --- | --- |
| Envío, contacto, apertura y retorno de WhatsApp | `nano-whatsapp-automation-lifecycle` |
| Historial y contexto canónico | `nano-canonical-messaging-integrity` |
| Identidad y adjuntos de Nano Personal | `nano-personal-evidence-flow` |
| Catálogo, capacidad y backend del modelo | `nano-model-capability-routing` |
| Compositor compacto aprobado, + y Complementos | `nano-compact-glass-composer` |
| Cristal, contraste y ventanas | `nano-glass-floating-windows` |
| Dock y teclado | `flutter-collapsible-dock` |
| Constraints y overflow | `flutter-fix-layout-issues` |
| Tamaño disponible y adaptación | `flutter-build-responsive-layout` |
| Comentarios y contratos Dart | `dart-write-documentation` |
| Recursos de animación y coste de renderizado | `motion-performance-audit` |
| Ejecución MCP o terminal PTY | `nano-mcp-terminal-integrity` |

Para implementar una animación concreta, utiliza la skill existente de ese
movimiento: `premium-microinteractions`, `hero-shared-transitions`,
`inertial-product-spin`, `gyroscopic-3d-tilt` o `cinematic-scroll-motion`.
Para material cristal, reutiliza `ios-liquid-glass`. No las cargues todas para
una corrección pequeña. Si alguna no está disponible, informa el límite y
trabaja sobre la implementación real en lugar de inventar su contenido.

## Corrección con responsabilidades pequeñas

- Haz el cambio mínimo en la capa propietaria. Reutiliza estado, persistencia,
  permisos, executor y componentes compartidos. No migres la arquitectura por
  seguir un ejemplo externo ni añadas una dependencia por conveniencia.
- Archivos nuevos o modificados: menos de 200 líneas. Extrae responsabilidades
  completas, con dependencias explícitas. No fragmentes arbitrariamente métodos
  ni comprimas declaraciones para esconder extensión.
- Comenta encima de cada función o componente modificado su responsabilidad,
  relación con el flujo y decisiones o límites relevantes. En Dart usa `///`
  para contratos y `//` para explicar pasos internos no evidentes.
- Revisa propiedad de tareas y recursos: quién inicia, observa, cancela y libera
  timers, streams, controladores, isolates, procesos y recursos nativos.
- Conserva cancelación y tiempos límite. Ante un envío o acción externa con
  resultado incierto, inspecciona evidencia antes de plantear un reintento.
- No muestres éxito por terminar la planificación. Distingue solicitado,
  ejecutado, observado y no verificable.

## Iteración dentro de la tarea

1. Revisa el diff y las llamadas afectadas después de editar.
2. Comprueba UTF-8, referencias, tamaño de archivo y análisis estático permitido.
   El MCP Dart instalado puede carecer de `analyze_files`; utiliza la CLI real
   para los archivos afectados cuando corresponda. No formatees todo el repo.
3. Corrige únicamente fallos relacionados que aporte esa revisión. Repite solo
   si hay cambios nuevos o evidencia nueva. Tras tres fallos iguales, cambia la
   hipótesis o informa el bloqueo; no repitas indefinidamente la misma acción.
4. Termina cuando el alcance esté implementado y la comprobación autorizada esté
   completada. Si el usuario prohibió pruebas, declara la validación de ejecución
   pendiente. No amplíes el alcance para consumir un ciclo adicional.

Este flujo no programa tareas periódicas, no ejecuta hooks ni delega trabajo.
Para pruebas futuras usa ARTEMIS únicamente cuando el usuario las solicite y
aplica sus reglas de exploración, diagnóstico y selección de dispositivo.
No redactes pruebas sobre pantallas o coordenadas supuestas.

## Entrega y aprendizaje

Indica qué cambió, qué evidencia respalda la corrección y qué queda pendiente.
Separa revisión estática, compilación, instalación y observación en dispositivo.
No prometas «100 % funcional», ausencia de bugs o menos calor sin evidencia.
Actualiza la skill específica cuando una causa y solución reutilizables estén
comprobadas; no guardes como regla una conjetura o un resultado de ejecución
no verificado. Nunca copies claves, conversaciones privadas o tokens a skills.
