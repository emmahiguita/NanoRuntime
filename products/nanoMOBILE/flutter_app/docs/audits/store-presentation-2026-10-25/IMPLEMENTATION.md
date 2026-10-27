# Presentación de Tienda — 25 de octubre de 2026

## Evidencia y alcance
La captura current-store.png corresponde a la ficha real abierta por el usuario.
El producto guardado tiene una imagen de una captura del catálogo de modelos;
no se sustituyó por una fotografía de muestra. Nombre, precio, SKU, descripción,
variantes e inventario conservan su fuente BusinessProduct y sus datos originales.

## Cambios
- Tarjetas y filas con jerarquía de imagen, categoría, nombre, precio y disponibilidad.
- Cuadrícula calculada por ancho real y escala de texto, con hasta tres columnas.
- Un solo menú de acciones existentes: ver, editar y compartir. Controles de 44 px.
- La ficha utiliza contentOwned y un solo GlassSurface/cierre. Desplazamiento del
  contenido independiente de editar/compartir; dos columnas en ventanas anchas.
- Las imágenes se muestran completas, sin viñeta oscura, con decodificación
  limitada a 1600 px de ancho. Errores de imagen y ausencia de imagen diferenciados.
- Vídeos identificados por extensión, sin atribuir resolución 4K ni simular un
  reproductor. El efecto de profundidad opcional conserva su integración existente.
- Estado de inventario compartido: sin cantidad significa consultar disponibilidad;
  cero es agotado; cantidad uno usa singular; producto desactivado indica pausado.
- Filtros y orden conservados; categoría Todos distingue su índice de un nombre
  guardado igual. Recuento de productos visible y etiquetas adaptadas al sistema.
- Colores del ColorScheme existente. No se agregan preferencias de apariencia.
- Formato aplicado al directorio de Tienda; los cambios ajenos a presentación en
  archivos de parallax son únicamente de formato.

## Límites
No se añadieron pagos, carrito, reseñas, entrega automática ni contenido comercial
inventado. Los vídeos se identifican como adjuntos; esta tarea no implementa un
reproductor. No se modificaron motores, mensajería ni persistencia del catálogo.
La presentación visual mejorada no corrige datos incompletos guardados por el usuario.

## Verificación
Análisis estático del módulo business: sin incidencias (analyze.log).
Inventario de archivos: source-inventory.json; todos menores de 200 líneas.
No se añadieron ni ejecutaron tests automatizados.
Compilación e instalación se registran por separado en build.log e install-receipt.json.
