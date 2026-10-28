# MNN de texto y conversación WhatsApp — 16-10-2026

## Causa comprobada y correcciones

El paquete Qwen2.5-Omni-3B-MNN declara `is_visual`, `is_audio` y `has_talker` en llm_config.json. Elegir ese archivo no lo convierte en texto: la fábrica de MNN sigue esas capacidades. Nano ahora construye Llm con la configuración de texto aplicada antes de crear el motor. Se conserva CPU y la plantilla real del paquete.

La medición anterior rondaba 4,55 GB PSS y 4,18 GB de swap PSS. La prueba aislada de texto quedó alrededor de 1,98 GB PSS durante tres turnos, sin atribuir esa cifra al proceso completo en cualquier escenario. Se mantiene la liberación ociosa bajo presión antes del despacho externo.

La sesión de conversación llega hasta MNN. Un cambio de sesión reinicia KV sin recargar pesos. Solo un prefijo realmente compatible se reutiliza. La cola y sus reintentos comparten un presupuesto de ejecución; no se entrega una respuesta inventada cuando falla el motor.

El parser de estado vivo reconocía pocas formas de incertidumbre y descartaba texto natural antes de la decisión. Se amplió el reconocimiento de ausencia de información y se mantiene la decisión posterior que bloquea actividad inventada, incluso mezclada con una admisión de desconocimiento. El reintento es una generación real, acotada; no usa respuestas fijas.

## Evidencia

- Prueba nativa aislada de tres turnos: conserva la corrección Lucas → Sara y guitarra. Primer token: 4411, 2077 y 1708 ms; reutilización KV en los dos turnos compatibles posteriores. No utiliza contactos ni envía mensajes.
- 84 pruebas Dart focalizadas aprobadas, incluidas sesión/ruteo, bienestar, actividad y regresiones personales.
- Análisis focalizado sin incidencias. El análisis global anterior tiene avisos existentes; no se declara limpio todo el repositorio.
- Compilaciones debug fullSideload y playStore realizadas durante la revisión. La última ampliación del parser se compiló en fullSideload.
- Bibliotecas MNN empaquetadas verificadas con alineación ELF de 16 KiB. No equivale a certificar una distribución release.
- Fixture RemoteInput local aprobado: receptor sintético, sin contacto WhatsApp. No prueba entrega por WhatsApp.
- La prueba ampliada de sesión/cancelación no terminó satisfactoriamente; no se cuenta como aprobada. Una ejecución corta posterior fue interrumpida por lanzar otra instrumentación y tampoco se cuenta.

## WhatsApp real: límite observado

El mensaje entró y MNN produjo salida, pero el parser instalado la descartó: `unknown=false`, sin volcar contenido privado. Prefill de 638–735 tokens tarda aproximadamente 30–45 segundos y un reintento repite buena parte del costo. Las cifras rápidas de la prueba aislada no representan esa ruta completa.

El corte de proceso de las 16:36 fue `stop ... due to installPackageLI`, no evidencia de crash nativo. El motor volvió a cargar después. No se puede declarar el flujo completo estable ni entrega confirmada solo por generar tokens o aceptar RemoteInput.

## Comparación

La comparación de fuentes de PocketPal y Gallery está en `pocketpal_gallery_nano_comparison_2026-10-16.md`. El patrón útil es mantener dueño del motor, sesión y plantilla correctos, medir configuración efectiva y separar inferencia de transporte. Que otra app converse en primer plano no demuestra el ciclo completo de WhatsApp de Nano.
