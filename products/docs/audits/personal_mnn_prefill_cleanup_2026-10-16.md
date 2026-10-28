# Depuración del costo de respuesta personal MNN

## Evidencia previa

El registro conservado en `personal_mnn_no_response_2026-10-16_1151.md`
mostró 44 801 ms de prefill, 46 780 ms hasta el primer token y 84 965 ms
de redacción incluyendo regeneración. El dispositivo usaba Qwen2.5 Omni 3B
en MNN CPU. No se atribuye esa demora a Qwen3 LiteRT.

## Cambio limitado

- El selector por metadatos aplica a MNN el sistema personal compacto existente.
- Conserva lectura del mensaje completo, autores, correcciones, fuentes,
  incertidumbre, prohibición de inventar acciones y separación de instrucciones/datos.
- La regeneración añade solo la corrección del defecto detectado, en lugar de
  repetir el contrato completo. Sigue limitada a una y sometida a las guardas.
- Registra longitudes de sistema, entrada e historial sin contenido privado.
- No reduce el historial canónico, modifica el modelo elegido, cambia el sampler,
  altera la cola ni elimina el aislamiento entre conversaciones.
- Componentes modificados: 35 y 163 líneas, con comentarios de mantenimiento.

## Límites y mantenimiento

Esto reduce texto que MNN debe procesar; no demuestra un porcentaje de mejora.
El backend aún reinicia su contexto antes de cada generación. Quitar ese reset
sin implementar identidad de sesión y reconciliación de tokens repetiría el
historial o mezclaría chats. No se introdujo esa optimización insegura.

Falta medir de nuevo TTFT, duración total, respuesta pertinente y cola con
notificaciones reales. Compilar no prueba naturalidad, entrega ni ausencia de
fugas. No se ejecutan pruebas automáticas por instrucción del usuario.

## Validación de esta entrega

- Análisis estático de las tres unidades relacionadas: sin incidencias.
- APK fullSideload profile: compilado (129 MB).
- Instalación con conservación de datos: `Success` en VGL7MVFMDYQG8T55.
- Android confirmó actualización a las 11:59:53 y arranque con PID 5108.
- En los últimos 1000 registros consultados no aparecieron FATAL EXCEPTION
  ni E/flutter; tampoco una nueva inferencia para comparar su latencia.
- Grafo de código actualizado. No se enviaron mensajes de prueba.
