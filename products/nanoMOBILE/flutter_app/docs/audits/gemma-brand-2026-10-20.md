# Logotipo original de Gemma

Se reemplaza la inicial genérica G por el PNG original de Google DeepMind,
sin redibujar, generar ni recolorear el archivo. Se conserva su transparencia.

- Fuente oficial: https://github.com/google-deepmind/gemma/blob/main/docs/images/favicon.png
- Revisión fijada: `92a84b68456f73221f881860892beaed06d6e895`.
- Descarga original: https://raw.githubusercontent.com/google-deepmind/gemma/92a84b68456f73221f881860892beaed06d6e895/docs/images/favicon.png
- SHA-256: `5bf74d2407276ae2d65f1366c120638f7e882cae0d8acc189276837d319cb6f7`.
- Archivo integrado: `assets/nano/gemma_official.png`.

## Presentación y alcance

`ModelBrandLogo` usa `GemmaBrandIcon` para los modelos conocidos del catálogo
Gemma y EmbeddingGemma. Tarjetas, detalles y carrusel comparten este componente.
Los archivos importados desconocidos mantienen su identificación local.
Gemini es otra marca: no se reemplaza el icono de sus sesiones web por Gemma.
No se modifican capacidades, selección, descarga, preferencias ni motores.

## Movimiento y mantenimiento

Gemma y Qwen reutilizan `OfficialModelBrandIcon`, sin duplicación de animadores:
una vuelta de entrada de 900 ms y reposo. El movimiento se desactiva cuando
Android pide reducir animaciones o navegación accesible. Flutter libera el
controlador implícito al desmontar el componente. No hay bucles ni temporizadores.
La imagen se decodifica a la resolución de pantalla y mantiene su proporción.

## Verificación

Los cuatro archivos Dart afectados tienen comentarios explicativos y menos de
200 líneas. Se usa formato, análisis estático y compilación fullSideloadDebug.
No se ejecutan pruebas automatizadas. La evidencia de compilación, empaquetado
e instalación se guarda en `gemma-brand-2026-10-20-build.json`.
