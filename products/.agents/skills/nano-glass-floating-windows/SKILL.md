---
name: nano-glass-floating-windows
description: Mantener el cristal compartido, ventanas flotantes y contraste de la navegación de Nano Mobile al corregir temas claros, oscuros o gris espacial.
---

# Nano: cristal, ventanas y navegación

- Descubrir componentes con el grafo; contrastar el código actual cuando el índice sea insuficiente.
- Usar GlassSurface como motor óptico. NanoOpticalSurface e InteractiveGlassCard son adaptadores; no duplicar filtros, reflejos ni controladores.
- Conservar la identidad de cada tema: Claro usa blanco con acentos verdes. No sustituirlo por azul al aplicar una estética iOS; Gris espacial es una preferencia independiente.
- Obtener claridad, densidad, desenfoque y habilitación de NanoThemeExtension. Una copia local debe conservar estos campos.
- Clasificar paletas mediante NanoPaletteBrightness y luminancia. NanoSpaceGrayColors implementa NanoColors; comprobar solo `is NanoDarkColors` lo identifica incorrectamente como claro.
- Definir los colores sobre contenedores, especialmente onSecondaryContainer: los valores Material predeterminados pueden dejar texto negro sobre fondo oscuro.
- Abrir selectores con showNanoGlassWindow, por encima de la navegación. Conservar Future<T?>, retorno al cancelar, contexto de cierre y opciones reales.
- Evitar doble marco y doble cierre: el presentador usa NanoWindowChrome.managed para contenido simple; un chat o diálogo con cabecera y GlassSurface propios debe declarar contentOwned. No superponer fondos, bordes o rellenos del antiguo bottom sheet.
- Las ventanas deben respetar área segura, teclado, ancho disponible y movimiento reducido. No volver a introducir showModalBottomSheet.
- En ventanas ancladas, `Semantics(scopesRoute: true)` requiere `explicitChildNodes: true`; omitirlo impide montar el menú. Mantener `namesRoute` y el nombre accesible. Causa observada tras pulsación manual: `nanoMOBILE/flutter_app/docs/audits/automation-whatsapp-popover/PLUS_FIX.md`.
- Mantener texto opaco y legible. El desenfoque se aplica al fondo recortado, no al contenido.
- Pausar animación ambiental al ocultar la ruta, suspender la app o reducir movimiento; liberarla en dispose.
- Medir los nombres del dock con su escala tipográfica real. Preservar destinos existentes, campo de escritura y reducción automática.
- Separar archivos fuente nuevos o refactorizados antes de alcanzar 200 líneas. Comentar qué hace cada responsabilidad y por qué existe.
- Si el usuario prohíbe tests, respetarlo: analizar, compilar y revisar manualmente solo las pantallas autorizadas.
- Verificar controles visibles antes de pulsar. No seleccionar modelos, guardar autonomía, enviar mensajes ni ejecutar herramientas al revisar diseño.
- Instalar con conservación de datos, registrar la huella del APK y restaurar la apariencia elegida tras una inspección temporal.
- No afirmar revisión visual de todas las ventanas a partir de una sola captura ni prometer una tasa de cuadros sin medirla.

Evidencia de la corrección: `nanoMOBILE/flutter_app/docs/audits/universal-glass-2026-10-24/`.
