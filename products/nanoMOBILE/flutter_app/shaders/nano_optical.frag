#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2 uResolution;
layout(location = 1) uniform float uTime;
layout(location = 2) uniform vec2 uPointer;
layout(location = 3) uniform float uIntensity;
layout(location = 4) uniform float uRefraction;
layout(location = 5) uniform float uFresnel;
layout(location = 6) uniform vec4 uBaseColor;
layout(location = 7) uniform vec4 uAccentCyan;
layout(location = 8) uniform vec4 uAccentLavender;

out vec4 fragColor;

// Distancia con signo a un rectángulo redondeado con radio 'r'
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 halfRes = uResolution * 0.5;
    vec2 p = uv - halfRes;
    
    float radius = 24.0;
    float dist = sdRoundedBox(p, halfRes, radius);

    // Descarte fuera del contenedor con antialiasing
    float alphaMask = 1.0 - smoothstep(-1.0, 1.0, dist);
    if (alphaMask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 normUv = uv / uResolution;

    // Normales de superficie virtual para refracción y Fresnel
    float edgeDist = abs(dist);
    vec2 normal = normalize(p / (halfRes + 0.001));

    // Vector de vista virtual (perpendicular a la pantalla)
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 N = normalize(vec3(normal * smoothstep(0.0, 30.0, edgeDist), 0.85));

    // 1. Efecto Fresnel en los bordes
    float fresnelFactor = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 2.5) * uFresnel;

    // 2. Iluminación especular interactiva vinculada al puntero
    vec2 pointerDist = uv - uPointer;
    float pointerLight = exp(-dot(pointerDist, pointerDist) / (180.0 * 180.0));

    // 3. Cáusticas y micro-ondas ópticas procedurales
    float caustics = sin(normUv.x * 14.0 + uTime * 0.7) * cos(normUv.y * 14.0 - uTime * 0.5) * 0.08;
    float caustics2 = sin((normUv.x + normUv.y) * 18.0 + uTime * 0.9) * 0.04;
    float waveTotal = (caustics + caustics2) * uRefraction;

    // 4. Composición cromática multicapa
    vec4 color = uBaseColor;

    // Mezcla de acento cian en el borde superior izquierdo
    float cyanWeight = clamp(-normal.x - normal.y, 0.0, 1.0) * fresnelFactor * 0.6;
    color = mix(color, uAccentCyan, cyanWeight);

    // Mezcla de acento lavanda en el borde inferior derecho
    float lavenderWeight = clamp(normal.x + normal.y, 0.0, 1.0) * fresnelFactor * 0.5;
    color = mix(color, uAccentLavender, lavenderWeight);

    // Destello blanco especular del puntero
    color += vec4(1.0, 1.0, 1.0, 0.0) * (pointerLight * 0.28 * uIntensity);

    // Brillo sutil de cáusticas
    color.rgb += vec3(waveTotal);

    // Borde biselado metálico hiperfino
    float rimHighlight = smoothstep(2.5, 0.5, edgeDist) * 0.35;
    color += vec4(rimHighlight);

    fragColor = color * alphaMask;
}
