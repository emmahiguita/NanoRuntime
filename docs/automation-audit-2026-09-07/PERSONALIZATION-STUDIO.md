# Personalización y actualización móvil — 2026-09-08

Continuación de las correcciones de mensajería, con la interfaz «Aprender de mis conversaciones» en Automatización → Ajustes → Agente personal. Se reutilizan PersonaRepository, PersonaContext, PersonaRetriever, ToneProfile y la misma base SQLite del módulo.

## Funciones implementadas

| Acción del usuario | Implementación |
|---|---|
| Seleccionar contactos/conversaciones | Identidad estable de notificaciones activas; perfiles manuales se vinculan explícitamente. Nunca se fusionan homónimos por nombre. |
| Importar historial | TXT WhatsApp individual (día/mes/año), CSV con roles y JSON v1; archivo completo guardado solo localmente tras aceptar. |
| Revisar lo importado | Lista de candidatos, avisos, selección individual y confirmación explícita de autoría del dueño. |
| Definir estilo | Global, contacto y rol personal/ventas/soporte; formal, casual, cercano o personalizado, extensión, emojis y uso del nombre. |
| Controlar aprendizaje | Opt-in mediante importación revisada; perfiles y aprendizaje por contacto pueden desactivarse. |
| Gestionar ejemplos/plantillas | Crear, editar, cambiar ámbito, desactivar y eliminar. Un ejemplo sin entrada original sigue siendo solo estilo. |
| Gestionar memorias | Crear, editar, desactivar, caducar y eliminar preferencias, relaciones, recuerdos, estilo y datos temporales. |
| Evitar mezcla de contactos | Ámbitos separados por hash de ConversationKey completo (paquete/cuenta incluidos); recuperación del contacto, rol y global. |
| Evitar aprender de Nano | Fuentes generadas excluidas y autoría verificada antes de activar ejemplos. No hay captura automática de respuestas del asistente como datos del dueño. |
| Retirar datos incorrectos | Eliminación individual o retirada del lote con sus registros y su copia de historial. Conserva datos manuales anteriores. |
| Recuperar contexto real | FTS4 sobre entrada histórica, ranking léxico y selección acotada; sin cargar el historial completo en el prompt. |
| Mantener hechos separados | Ejemplos no acreditan estado actual; datos temporales y de negocio importados no reemplazan los hechos operativos de BusinessFacts. |
| Generación | Personalización determinista previa al writer existente; no añade otra llamada semántica al LLM. |
| Ver datos disponibles | Contadores reales, procedencia, contactos, ejemplos, memorias, plantillas y hasta 100 lotes recientes. |

## Correcciones de esta continuación

- Migración SQLite v7 conserva tablas y filas de usuario; repara los triggers de edición/borrado FTS4 y reconstruye únicamente su índice derivado.
- Importaciones atómicas y deduplicadas; no aceptan IDs que puedan sobrescribir memorias manuales. Revisar más datos del mismo lote conserva su historial y actualiza su contador.
- Datos de contactos sin perfil siguen visibles en el selector y pueden corregirse.
- Fallos de lectura no se presentan como perfiles vacíos; la UI bloquea edición si no pudo cargar los datos.
- Cambio rápido de contacto no mezcla resultados pendientes de otro ámbito.
- Desactivar un perfil excluye su estilo, ejemplos y memorias particulares de nuevas respuestas. Desactivar aprendizaje excluye sus ejemplos, conservando las preferencias manuales.
- El contexto completo queda acotado; memorias y ejemplos largos se omiten completos para evitar cortar negaciones o condiciones.
- Historial TXT no empareja avisos, multimedia, eliminados ni autores de grupos. Fechas inválidas y CSV mal formado se rechazan con explicación.
- El perfil del dueño tiene guardado explícito y conserva los ajustes de estilo del Studio.
- La entrega UI/headless conserva una sola instancia de ejecución y el ACK del inbox espera la terminación del gate.

## Límites de esta versión

Máximo 2 MB, 5000 mensajes y 1000 candidatos por archivo; un contacto por importación. La app no lee directamente la base privada de WhatsApp: usa archivos exportados por el usuario. Recuperación léxica local, sin embeddings ni entrenamiento de pesos. Se seleccionan como máximo dos ejemplos y tres memorias; ejemplos de más de 500 caracteres o entradas de más de 200 no entran completos al prompt, y memorias mayores de 450 se conservan para edición pero se omiten del contexto. Los registros temporales y los datos de negocio importados requieren verificación operativa antes de afirmarlos como estado presente. Los límites operativos de inbox, dedupe y scheduling del informe anterior siguen vigentes.

No se crearon ni ejecutaron suites de tests en esta continuación. La compilación y la instalación no demuestran por sí solas todos los escenarios de WhatsApp: la revisión manual de conversaciones corresponde al usuario. El build release local utiliza la firma de desarrollo configurada en el proyecto; no equivale a un APK firmado para distribución pública.

El resultado final de compilación, hash e instalación queda en `mobile-release-2026-09-08.json` cuando se complete la actualización física.
