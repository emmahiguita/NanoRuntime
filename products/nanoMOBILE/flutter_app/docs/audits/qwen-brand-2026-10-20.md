# Identidad y fichas de Qwen

## Fuente de la marca

Se incorporó sin redibujar ni recolorear el PNG original utilizado por el blog
oficial de Qwen. Su configuración identifica `/img/logo.png` como icono del sitio:
https://github.com/QwenLM/qwenlm.github.io/blob/main/config.yml

- Archivo local: `assets/nano/qwen_official.png`.
- Original fijado: https://raw.githubusercontent.com/QwenLM/qwenlm.github.io/abaadc6da2ef9c3f444b738018b0cec32bb0b4f7/static/img/logo.png
- SHA-256: `4a36e944efd4d11761ba3a98518493cb078364939ba0899d7bdd58429a454ae5`.
- Conserva la transparencia y los colores violeta y blanco del original.
- No es un icono creado por Nano ni se descargará al entrar a la pantalla.

## Aplicación

El catálogo, sus detalles y el carrusel comparten `ModelBrandLogo` y ahora usan
`QwenBrandIcon`. DeepSeek destilado de Qwen conserva su identidad DeepSeek.
Un GGUF desconocido no adquiere identidad ni capacidades por contener «Qwen» en
el nombre del archivo. Sesiones IA muestra el mismo símbolo en las URLs HTTPS
`qwen.ai` y `chat.qwen.ai`; el selector de proveedor también lo reutiliza.
La sesión web informa que requiere Internet y no se confunde con inferencia local.

## Movimiento y mantenimiento

El símbolo da una vuelta de entrada de 900 ms y después permanece quieto.
No hay repetición, temporizadores ni controladores manuales. Flutter dispone el
controlador implícito al desmontar el widget. Si el sistema pide reducir movimiento
o navegación accesible, se monta directamente la imagen estática, incluso cuando
la preferencia cambia durante un giro. La textura se decodifica al tamaño de pantalla
y `RepaintBoundary` limita el repintado al icono.

## Información publicada frente a integración

Las descripciones se asignan únicamente a variantes conocidas del catálogo:

- Qwen2.5 Instruct: generación de texto; no se presenta como visión o transcripción.
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct
  https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct
- Qwen3 0.6B: modelo de texto. El archivo instalado por catálogo es el artefacto
  LiteRT no-think, diferenciado del modo thinking del original.
  https://huggingface.co/Qwen/Qwen3-0.6B
  https://huggingface.co/litert-community/Qwen3-0.6B-int4
- Qwen3.5 0.8B y 2B: el original admite imágenes; las rutas de texto en Nano no
  reciben imágenes directamente. El artefacto VL mantiene su integración pendiente.
  https://huggingface.co/Qwen/Qwen3.5-0.8B
  https://huggingface.co/Qwen/Qwen3.5-2B
- Qwen2.5 Omni 3B: modalidades del original separadas de la ruta MNN de texto.
  https://huggingface.co/Qwen/Qwen2.5-Omni-3B
- Qwen3 ASR: transcripción, incluido español; adaptador pendiente en Nano.
  https://huggingface.co/Qwen/Qwen3-ASR-0.6B
  https://huggingface.co/Qwen/Qwen3-ASR-1.7B

Cada ficha ofrece «Ficha oficial de Qwen» y «Fuente del archivo». La primera
documenta el modelo original; la segunda conserva la procedencia de la conversión.
No se cambiaron selección, motores, descargas, permisos ni preferencias.

## Verificación

- Formato Dart aplicado a los nueve archivos de código afectados.
- Análisis estático enfocado: sin incidencias.
- Los nueve archivos tienen menos de 200 líneas físicas y comentarios explicativos.
- No se ejecutaron pruebas automatizadas ni se manipuló el teléfono.
- Compilación y evidencia del paquete: véase `qwen-brand-2026-10-20-build.json`.
- El aspecto final en claro, oscuro y horizontal queda pendiente de revisión manual
  en el teléfono, según la instrucción del usuario.
