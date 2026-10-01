# Conversación móvil: diagnóstico con dispositivo real

Fecha: 1 de octubre de 2026. Dispositivo: Oppo CPH2557, conectado por ADB.

## Alcance y límites

Se inspeccionaron Logcat, el runtime local y código real. Las comparaciones usaron
preguntas controladas en el motor del teléfono, sin enviar mensajes a contactos.
No se ejecutó una suite de tests. Estas mediciones no prueban comprensión universal
ni entrega final de WhatsApp; no corresponde declarar el sistema al 100%.

## Fallos encontrados y correcciones

1. El runtime enviaba ChatML a Llama 3. La familia ahora se detecta desde el
   template del GGUF y usa cabeceras Llama y cierres eot_id.
   Fuente: [formato oficial de Meta](https://github.com/meta-llama/llama-models/blob/main/models/llama3_2/text_prompt_format.md).
2. La pregunta sobre Nano podía tratarse como conocimiento externo. La identidad
   de la aplicación ahora procede de datos compartidos y configuración real.
3. El contexto personal estructurado alcanzaba aproximadamente 5.000 caracteres
   incluso para mensajes cortos. Se conserva el contrato de seguridad en una
   versión compacta, sin eliminar el formato estructurado de estado vivo/transferencias.
4. Memoria y fecha variables invalidaban la caché del sistema. Se trasladaron al
   turno; las instrucciones reutilizables permanecen en el sistema. El historial
   viaja como roles reales y solo incluye entradas factuales.
5. El parser descartaba texto conversacional válido sin el marcador Respuesta:.
   Personal simple admite texto natural; ventas y estado vivo siguen requiriendo
   su contrato. No se fabrica una respuesta de reemplazo.
6. Se bloquea salida con delimitadores de protocolo, cabeceras de roles o
   razonamiento sin resolver; quitar etiquetas no vuelve factual una respuesta.
7. Dos arranques concurrentes escribían el mismo nanortime.tmp. La extracción,
   SHA-256 y rename ahora están protegidos por un lock de proceso en un responsable
   separado. Al principio no aparecieron zombis; durante el cambio de modelo
   se observaron dos linker64 en estado Zs, hijos del worker nanoshell.
8. Qwen devuelve a veces un bloque think vacío antes de la respuesta.
   El ajuste más reciente retira únicamente ese prefijo completo y vacío,
   manteniendo el rechazo de bloques no vacíos/incompletos y protocolos filtrados.

## Medidas reales después de corregir el formato nativo

Cada caso usa instrucciones de producción y, cuando corresponde, historial
controlado con roles user/assistant. Tiempo total de la petición, no solo decodificación.

| Modelo instalado | Identidad de Nano | Continuidad | Corrección |
| --- | ---: | ---: | ---: |
| Llama 3.2 1B Q4_K_M | 32,2 s | 55,2 s | 9,6 s |
| Qwen 3.5 0.8B Q4_K_M | 29,4 s | 42,1 s | 9,9 s |

No son resultados estadísticos ni una comparación fría/caliente perfectamente
equivalente. El sistema reutiliza caché: la corrección es un turno posterior.
En Qwen, las trazas nativas registraron aproximadamente 2,2–2,5 s al primer token
en dos generaciones; esa cifra no incluye toda la preparación fría del prefijo.

### Calidad observada

- Llama dejó de emitir etiquetas internas en los tres casos, pero confundió
  acciones del interlocutor y rechazó una corrección cotidiana.
- Qwen explicó la identidad de Nano; en continuidad reconoció el catálogo
  terminado pero repitió preguntas en vez de resolverlas todas.
- Qwen reconoció parte de la corrección, pero añadió una pregunta innecesaria.
- Ninguno queda validado como modelo ideal para conversación completa.
- Activar razonamiento prolongado no corrige un protocolo incompatible ni
  aumenta automáticamente comprensión; requiere evaluar coherencia y latencia.

## Estado de instalación

Se compiló el motor Android ARM64 release y se verificó su formato ELF/PIE.
Se instaló una actualización release y posteriormente una APK de diagnóstico
para acceder al registro nativo. Se conservaron datos y modelos del usuario.

La APK de diagnóstico instalada incorpora el formato Llama, contexto compacto,
historial nativo, parser de texto simple y extracción serializada.

El ajuste del bloque think vacío está en código y pasa análisis estático, pero
todavía NO está instalado. La compilación final quedó bloqueada por cambios
simultáneos de otro chat: AppMatchKind añadió alias/fuzzy y el switch del
planificador aún no cubre esos casos. El usuario confirmó la edición concurrente.
No se modificaron esos archivos para evitar interferir con el otro trabajo.

Se restauró Llama, el modelo activo antes de la comparación, mientras queda
pendiente compilar el ajuste de Qwen. No se afirma que Llama resuelva la calidad.

La sesión se reinició normalmente sin borrar datos. Después del reinicio se
confirmó Llama cargado y un solo daemon vivo, sin esos dos zombis. Es limpieza
de sesión, NO una corrección definitiva del recolector de procesos.
El recolector nativo solo espera PIDs en su registro; reemplazar la entrada del
daemon antes de recoger el hijo anterior deja una vía de pérdida de seguimiento.
Ese ciclo de vida se corrigió después, como se detalla en la actualización siguiente.

## Actualización: recolector corregido e instalado

- El registro conserva cada PID, incluidos los retirados al reemplazar un daemon,
  hasta recogerlo con waitpid(PID, WNOHANG), o confirmar que ya no es un hijo.
- Reemplazo, señal, registro y recolección comparten exclusión mutua. No se
  sobrescribe un PID pendiente ni se mata un PID fuera del registro.
- Se reserva memoria e inicia el único recolector antes del fork; si falla,
  no se crea un hijo sin seguimiento. No hay un hilo por proceso.
- No se usa waitpid(-1) en este recolector: las tareas y PTY mantienen su ownership.
- Los intervalos solicitados son 250 ms con hijos y 2 s sin hijos. Un estado Z
  transitorio entre terminar y recoger no equivale a un zombi persistente.

Archivos: worker_jni.c (125 líneas), worker_daemon_registry.c (157),
worker_daemons_jni.c (44) y worker_daemon_registry.h (13). Las interfaces JNI
existentes se conservaron; CMake incorpora los dos módulos nuevos.

La librería Android compiló. Se creó una APK interna de diagnóstico a partir
de la última APK válida, sin integrar los cambios incompletos del otro chat.
Se compararon por SHA-256 las 721 entradas originales: solo cambió
lib/arm64-v8a/libnanoshell.so. Se añadieron tres metadatos de firma; se verificaron
certificado, alineación y firma. La instalación como actualización fue exitosa.

SHA-256 de libnanoshell.so, igual en build y teléfono:
1e41156d5f56a36c8920d3bbb19c4b2f1ce921445282e566a3c4b29096da2d27.

Artefacto: build/app/outputs/flutter-apk/app-fullsideload-collector-debug.apk.
Es una APK de desarrollo, no una distribución de producción ni una compilación
del árbol Dart actual. Los primeros paquetes rechazados no se instalaron.

Después de instalar se observaron un worker y un motor vivos, sin estados Z.
Con autorización del usuario se verificaron cuatro cambios manuales:
Llama -> LFM -> Llama -> LFM -> Llama, sin reiniciar la app ni el worker.
El logcat real confirmó `reaped detached` para los PIDs 18056, 21553, 21657
y 21777, todos con status=9. Cada PID anterior desapareció de la tabla de
procesos; en cada captura permaneció un solo motor, sin estados Z.
Al terminar: app PID 17390, worker PID 17903, motor PID 22257; Llama restaurado.
Esta evidencia valida los reemplazos observados, no todos los fallos posibles.
Este cambio no declara resuelta la calidad conversacional de los modelos.

## Siguiente validación manual

1. Terminar o coordinar la edición del otro chat.
2. Compilar e instalar la APK final sin borrar datos.
3. Repetir mensajes reales: saludo, identidad, dos preguntas en un párrafo,
   referencia al turno anterior, corrección y dato desconocido.
4. Separar tiempo de recuperación, preparación fría, primer token y respuesta total.
5. Verificar decisión y entrega de WhatsApp, no solamente aceptación de RemoteInput.
6. Aprobar un modelo solo si conserva autores, tiempos y todas las preguntas,
   responde sin inventar y cumple la latencia acordada.

## Organización del cambio

Los módulos nuevos son pequeños y comentados: nano_identity_context.dart,
notification_draft_writer_personal_prompt.part.dart, llama_chat_format.rs y
EngineBinaryInstaller.kt. Los archivos Dart modificados por este trabajo están
bajo 200 líneas. Los supervisores nativos preexistentes son mayores de 200 líneas;
se extrajo lógica, pero no se realizó una reestructuración global de esos módulos
durante este diagnóstico para no ampliar el alcance ni interferir con otros cambios.
