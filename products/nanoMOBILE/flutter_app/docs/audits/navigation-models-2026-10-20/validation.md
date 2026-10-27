# Validación de la auditoría

Fecha: 20 de octubre de 2026.

## Comprobaciones completadas

- Formato Dart aplicado a las fuentes modificadas.
- Análisis estático de iconografía FeatherCore, navegación, presentación de modelos, catálogo e importador Hugging Face: **No issues found**.
- Recuento físico de 42 archivos fuente de esta revisión: todos por debajo de 200 líneas. Detalle en `source-maintenance.json`. Esto no significa que todo el repositorio heredado cumpla ese límite.
- Consulta pública de los 33 registros: 32 archivos individuales coinciden con el SHA-256 del catálogo, fijado a una revisión; el paquete MNN mantiene verificación separada por archivo. No se descargaron los pesos para estas comprobaciones.
- Cinco recursos gráficos propios, con canal RGBA y transparencia real comprobada. Los prompts y la herramienta integrada utilizada están documentados en `icon-generation.json`.
- Compilación final: `assembleFullSideloadDebug`, **BUILD SUCCESSFUL in 35s**.
- APK final: `build/app/outputs/flutter-apk/app-fullsideload-debug.apk`, 190656736 bytes.
- SHA-256 del APK: `9218b3c875dea07b2635a0d276db5f7e8d697b05075a002879732356c258abde`.
- Los cinco PNG están dentro del APK y coinciden byte por byte con sus fuentes. Evidencia en `apk-evidence.json`.
- Grafo local actualizado con `graphify update .`.

## Instalación y observación en el dispositivo

Se instaló una compilación intermedia en CPH2557 conservando los datos. Se observó la pantalla inicial del catálogo actualizado en modo claro: categorías OCR y multimodales visibles, títulos en dos líneas y disponibilidad separada de cantidad de archivos. Esa observación ocurrió antes de incorporar los cuatro recursos gráficos finales de navegación y los últimos ajustes.

El usuario pidió continuar con código y compilación mientras utiliza el teléfono. **El APK final no se instaló y la inspección visual final se dejó pendiente**. No se afirma que se haya recorrido la ficha final, la barra con todos sus iconos finales, el modo oscuro ni la orientación horizontal.

No se enviaron mensajes ni se ejecutó inferencia para atribuir rendimiento o calidad a los modelos. No se ejecutaron pruebas automatizadas.

## Revisión manual pendiente

1. Instalar el APK final y abrir el catálogo. Comprobar títulos, grupos y disponibilidad con el tamaño de texto habitual y ampliado.
2. Expandir la píldora: deben aparecer Inicio, Modelos, Terminal y Ajustes con iconos propios. El tirador superior debe abrir escritura sin interceptar los destinos.
3. Cambiar entre tema claro y oscuro; revisar contraste de texto, cristal y selección. Verificar también la orientación horizontal.
4. Abrir una ficha LLM, una de OCR y una de embeddings. Las dos últimas deben explicar el adaptador pendiente y no ofrecer carga como chat.
5. Revisar favoritos, cancelación/progreso, compartir y comparación. No es necesario descargar modelos pesados para revisar el diseño.
6. Iniciar dictado propio de la barra y salir o cambiar de editor; comprobar que se detiene la captura. Los callbacks externos mantienen su propio ciclo de vida.

## Límites del entorno

- Gradle conserva advertencias de obsolescencia previas; no se migró su versión durante este cambio de interfaz.
- La consulta Git devolvió `fatal: bad object HEAD`. No se modificó ni intentó reparar el historial. La validación se apoya en las fuentes actuales, el análisis estático, la compilación y los artefactos registrados.
- La actualización de Graphify omitió la visualización HTML por tamaño del grafo y avisó de archivos JSON de diagnóstico sin nodos. Sí actualizó sus archivos de grafo e informe.
