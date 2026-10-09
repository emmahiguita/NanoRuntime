#include <flutter/runtime_effect.glsl>

// product_depth_parallax.frag
//
// QUÉ HACE:
// Fragment Shader de alto rendimiento para reproyección 2.5D de imágenes con mapa de profundidad (DIBR).
//
// CÓMO FUNCIONA:
// - Aplica un factor de sobre-escala (overscan 1.08x) para eliminar franjas vacías al inclinar la imagen.
// - Muestrea el mapa de profundidad en escala de grises y calcula el desplazamiento UV relativo al centro.
// - Aplica un brillo especular direccional (specular parallax shine) simulando reflejos de luz física.
//
// POR QUÉ:
// Provee una experiencia visual 3D interactiva en GPU sin requerir mallas poligonales pesadas.

uniform vec2 uSize;
uniform vec2 uTilt;       // Vector de inclinación suavizado (-1.0 a 1.0)
uniform float uStrength;  // Intensidad del desplazamiento (ej. 0.025)
uniform float uSpecular;  // Intensidad del brillo especular (0.0 a 1.0)

uniform sampler2D uImage;
uniform sampler2D uDepth;

out vec4 fragColor;

void main() {
    // 1. Coordenadas normalizadas con factor de overscan (1.08x)
    vec2 rawUv = FlutterFragCoord().xy / uSize;
    vec2 uv = (rawUv - 0.5) * 0.925 + 0.5;

    // 2. Muestreo de profundidad normalizada (0.0 = fondo, 1.0 = frente)
    float depth = texture(uDepth, uv).r;
    float centeredDepth = depth - 0.5;

    // 3. Desplazamiento UV guiado por el vector de inclinación
    vec2 offset = uTilt * centeredDepth * uStrength;
    vec2 displacedUv = clamp(uv + offset, 0.001, 0.999);
    vec4 baseColor = texture(uImage, displacedUv);

    // 4. Brillo especular dinámico reactivo a la luz aparente
    vec2 lightDir = normalize(uTilt + vec2(0.35, -0.55));
    float shineFactor = smoothstep(0.72, 0.98, dot(lightDir, offset * 28.0 + vec2(0.5)));
    vec3 specularShine = vec3(1.0, 1.0, 1.0) * shineFactor * (uSpecular * 0.16) * depth;

    // 5. Composición final
    fragColor = vec4(baseColor.rgb + specularShine, baseColor.a);
}
