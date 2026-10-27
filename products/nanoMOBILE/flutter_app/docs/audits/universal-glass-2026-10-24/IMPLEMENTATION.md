# Ventanas, cristal y legibilidad de Nano

Fecha de cierre: 25 de octubre de 2026 (America/Bogota).

## Cambios

- Un solo motor GlassSurface para tarjetas, adaptadores ópticos, ventanas y carcasa del dock. Lee los ajustes globales de transparencia, claridad y desenfoque.
- Reflejo ambiental opcional con ciclo de vida; el contenido conserva su propia opacidad. Se respeta reducción de movimiento.
- Las 60 aperturas inferiores localizadas se migraron a ventanas flotantes. La revisión de código no encuentra llamadas showModalBottomSheet restantes en lib/.
- Marco centrado, limitado al espacio disponible, con cierre visible, desplazamiento del contenido y ajuste al teclado. Por defecto usa el navegador raíz para cubrir también la barra.
- Gris espacial se clasifica por luminancia: antes la comprobación por tipo lo construía como tema claro. Se corrigieron también las utilidades ópticas y el contraste sobre contenedores secundarios.
- Automatización conserva los ajustes ópticos globales al adaptar sus componentes; ya no los reinicia con valores locales predeterminados.
- La barra y la píldora reducida usan el cristal compartido. Se eliminó la segunda lente del editor. Los nombres se miden con la escala tipográfica real y la opción seleccionada corrige su contraste.

## Comprobación

Análisis estático focalizado sin incidencias. El análisis completo no registró errores; mantiene una advertencia y 46 avisos de estilo existentes fuera de estos componentes. No se ejecutaron pruebas automatizadas.

Compilación: fullSideloadDebug. Instalación conservando datos: adb install -r. La huella y el tamaño del APK final se registran en delivery-receipt.json.

Revisión manual en el teléfono conectado: ventanas de autonomía e inferencia en gris espacial, visibilidad del dock y contraste del segmento local. La captura inicial del segmento reveló texto negro sobre oscuro; se corrigió y la captura inference-delivery.png muestra el texto legible. No se guardaron cambios de autonomía o inferencia.

El inventario de migración verifica llamadas de código; no significa que se haya recorrido visualmente cada ventana. No se midió una tasa de cuadros. Los selectores nativos de Android conservan su presentación del sistema.

## Mantenimiento

Archivos compartidos nuevos/refactorizados del motor, ventanas, tema y dock: menos de 200 líneas por archivo, con comentarios por responsabilidad. Esto no constituye una auditoría del tamaño de todos los archivos heredados del repositorio.

Guía del proyecto: .agents/skills/nano-glass-floating-windows/SKILL.md.

## Estado final

El usuario eligió dejar **Gris espacial**; se conservó esa preferencia. La última instalación confirmó Success y corresponde a build-installed-final.log. No se siguió navegando por el teléfono al observar cambios de pantalla durante el uso del dispositivo.

La corrección del ancho del dock está compilada e instalada y usa medición real de texto. La captura navigation-wide-final.png corresponde a otra pantalla que se abrió durante la revisión; no se utiliza como prueba visual de las cuatro etiquetas del dock. No se afirma una comprobación visual completa de cada ruta o escala tipográfica.
