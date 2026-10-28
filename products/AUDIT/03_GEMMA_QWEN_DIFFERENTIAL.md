# 03 — GEMMA VS QWEN DIFFERENTIAL (plan + evidencia actual)

## Evidencia actual

- **Gemma-4-E2B-it.litertlm (2.6 GB) está en el dispositivo pero NUNCA se cargó**: grep en todas las capturas logcat de la sesión (`logcat_wa.txt`, `logcat_infer.txt`, `logcat_live.txt`) no devuelve ninguna línea de carga/inferencia de gemma. **UNVERIFIED**.
- **HYPOTHESIS**: Gemma 4 E2B probablemente NO cabe/arranca en este dispositivo: 8 GB RAM con ~1.9 GB disponibles en medición de sesión, modelo 2.6 GB en disco (q4, ~2.5-3 GB en RAM) + activaciones. La afirmación "Gemma funciona encima de LiteRT" no aplica a ESTE hardware hasta demostrarlo.
- Qwen3-0.6B LiteRT SÍ funciona en el mismo runtime (medido: carga CPU 3.5 s, decode hasta 15.1 tok/s) pero falla calidad (echo, repeated_characters) — evidencia de que el RUNTIME funciona y el MODELO es débil para la tarea.

## Lo que esta prueba separa

| Resultado | Conclusión |
|---|---|
| Gemma carga y responde coherente, Qwen no | Sospechoso: artefacto Qwen (tokenizer/template/KV 1280) o tamaño de modelo, no el runtime |
| Ambos fallan igual | Sospechoso: ConversationCore / prompt / persona / history (no el runtime) |
| Ambos funcionan | El runtime es sano; el problema era el modelo 0.6B q4 + persona vacía |

## Procedimiento (device test)

1. Cargar `gemma-4-E2B-it.litertlm` como chat manual desde UI (o `specificModel` en automatización) y registrar `ModelSupervisor`/`LiteRtChannel` logs. Esperado: OOM o fallo de carga en MT6833/8GB — registrar el error exacto.
2. Si carga: ejecutar el guion idéntico en chat manual:

```
Hola
¿Cómo te llamas?
Yo soy hombre.
¿Quién es hombre?
Mi nombre es Emmanuel.
¿Cómo me llamo?
Tú eres Nano.
¿Quién eres tú?
No uses emojis.
¿Por qué respondes así?
Eso que respondiste está mal.
Corrige tu respuesta.
```

3. Repetir el mismo guion con Qwen3-0.6B (LiteRT) y con Qwen2.5-1.5B (LiteRT ekv4096, descargado y SHA verificado 2026-10-16, pendiente de colocar en `files/nano/models/`).
4. Capturar por turno: TTFT, tok/s, tokens, raw output, rejected?, personaChars, historyTurns, backend, `kvTokensAfter`.

## Estado

- Modelo 1.5B Q8 ekv4096: descargado (1523.9 MB), SHA256 verificado `faa60663…dc9` ✓. Falta: push a dispositivo + registro.
- Modelo Gemma: en disco, sin probar.
- Resultados: PENDIENTES DE EJECUCIÓN EN DISPOSITIVO (requieren el usuario enviando el guion).
