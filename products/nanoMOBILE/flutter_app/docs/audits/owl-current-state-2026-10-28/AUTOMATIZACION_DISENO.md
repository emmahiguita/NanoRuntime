# Automatización: revisión y ajustes

- Las tarjetas de Oscuro usan superficies negras y grafito del tema compartido,
  sin el degradado azul que antes anulaba la paleta global. Gris espacial y
  Claro conservan sus propias paletas.
- Los accesos utilizan los iconos FeatherCore existentes y el recurso propio
  de WhatsApp; se mantienen sus acciones y la estructura de la pantalla.
- El selector de autonomía dispone de un área táctil mínima de 48 puntos. La
  cuadrícula existente pasa a una columna con poco espacio o texto ampliado.
- Se corrigió el texto de Terminal para no prometer acceso root.
- Se aplicaron 89 correcciones automáticas de sintaxis y estilo y se actualizó
  el uso obsoleto de compartir en iOS. `dart analyze lib`: sin observaciones.
- El APK `fullSideloadDebug` compiló correctamente. No se ejecutaron pruebas
  ni se inspeccionó visualmente la versión en un dispositivo en esta revisión.
- El OPPO no apareció conectado durante la instalación; el APK no fue instalado.
- Algunas fuentes heredadas que recibieron correcciones mecánicas siguen por
  encima de 200 líneas; su división completa queda pendiente. Los componentes
  nuevos y los tres archivos principales del ajuste visual están bajo 200.
