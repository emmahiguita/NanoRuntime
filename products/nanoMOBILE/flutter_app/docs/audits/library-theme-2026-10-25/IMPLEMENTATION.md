# Biblioteca: tema heredado y cristal único

La captura mostró un panel azul oscuro dentro de otro marco claro. La vista tenía un gradiente oscuro fijo, componentes con isDark: true y texto blanco independiente del tema.

## Presentación corregida

La biblioteca conserva su cabecera y cierre, declara NanoWindowChrome.contentOwned y dibuja una única GlassSurface. Se retiraron la segunda superficie, los márgenes duplicados y el gradiente oscuro. El tema seleccionado controla los colores de cabecera, búsqueda, pestañas, filtros, carpetas, lista, cuadrícula, pie y componentes de Tienda. Los controles interiores usan fondos ligeros sin más filtros de cristal.

Los menús de archivos, carpetas, orden, formato y selección se abren flotantes mediante el presentador compartido. Devuelven claves a las mismas acciones existentes. Cancelar devuelve null; se comprueba que el contexto siga montado antes de invocar callbacks. El envío sin selección permanece deshabilitado y se presenta como tal.

Tienda reutiliza el buscador sincronizado de Biblioteca. Al borrar la consulta se limpian el campo y el filtro; la descripción de búsqueda menciona nombre, categoría y SKU, que sí forman parte del filtro real.

## Conservación y comprobación

No se modificaron almacenamiento, importadores, extracción PDF, vistas de contenido real, compartición de archivos ni catálogo persistido. Se conservaron las claves de los filtros y de orden y los callbacks de las acciones. Las categorías de carpetas y los indicadores sobre fotos/videos mantienen su función; no se recolorea el contenido real de un documento o medio.

Los cambios se hicieron por componente mediante modificaciones explícitas. Una reescritura automática masiva fue rechazada por revisión de seguridad y no se ejecutó; la corrección se completó con una alternativa acotada y revisión estática.

Análisis estático de Biblioteca/Tienda sin incidencias. Todos los archivos modificados están por debajo de 200 líneas. No se escribieron ni ejecutaron tests automáticos, ni se abrieron/importaron/enviaron archivos desde el teléfono para verificar el diseño. La comparación visual inicial utiliza la captura del usuario; no se afirma haber recorrido cada tema en el dispositivo.

Compilación fullSideloadDebug satisfactoria e instalación confirmada con Success, conservando datos. El APK instalado se identifica en delivery-receipt.json.
