#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2 uResolution;
layout(location = 1) uniform float uTime;
layout(location = 2) uniform vec2 uPointer;
layout(location = 3) uniform float uPointerEnergy;
layout(location = 4) uniform float uIntensity;
layout(location = 5) uniform vec4 uAccentPrimary;
layout(location = 6) uniform vec4 uAccentSecondary;

out vec4 fragColor;

// 2D Rotation
mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

// Pseudo-random hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth Value Noise with analytical gradient feel
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Multi-octave Fractal Brownian Motion (FBM)
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 r = rot(0.37);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = r * p * 2.02 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// Silk Ridge Function: produces ultra-thin luminous filaments
float ridge(vec2 p) {
    float n = sin(p.x * 2.5 + cos(p.y * 2.0)) * cos(p.y * 2.5 + sin(p.x * 2.0));
    return pow(1.0 - abs(n), 4.5);
}

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 st = (uv - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

    float t = uTime * 0.22;

    // 1. Touch & Pointer Disturbance
    vec2 pointerSt = (uPointer - 0.5 * uResolution) / min(uResolution.x, uResolution.y);
    vec2 pDelta = st - pointerSt;
    float pDist = length(pDelta);
    float pRipple = sin(pDist * 16.0 - uTime * 4.0) * exp(-pDist * 3.5) * uPointerEnergy * 0.12;
    st += normalize(pDelta + 0.0001) * pRipple;

    // 2. Multi-tier Domain Warping (Silk & Fluid Wave Physics)
    vec2 q = vec2(
        fbm(st + vec2(0.0, 0.0) + vec2(t * 0.15, -t * 0.10)),
        fbm(st + vec2(5.2, 1.3) + vec2(-t * 0.12, t * 0.14))
    );

    vec2 r = vec2(
        fbm(st + 3.2 * q + vec2(1.7, 9.2) + vec2(t * 0.20, -t * 0.16)),
        fbm(st + 3.2 * q + vec2(8.3, 2.8) + vec2(-t * 0.18, t * 0.22))
    );

    float f = fbm(st + 3.6 * r + vec2(0.0, t * 0.08));

    // 3. Silk Caustic & Filament Layer
    vec2 silkCoord = st * 3.2 + r * 2.4 + rot(t * 0.3) * q;
    float filaments = ridge(silkCoord + vec2(t * 0.3, -t * 0.2));
    float filaments2 = ridge(silkCoord * 1.8 - vec2(t * 0.4, t * 0.25));
    float totalFilaments = filaments * 0.65 + filaments2 * 0.35;

    // 4. Volumetric Core Glow (Center breathing light)
    float coreDist = length(st * vec2(0.9, 1.2) - vec2(0.0, 0.05));
    float coreGlow = exp(-coreDist * 2.8) * (0.8 + 0.2 * sin(uTime * 0.8));

    // 5. Rich Chromatic Palette (Deep Space, Sapphire, Cyan, Royal Violet, Core White)
    vec3 deepBackground = vec3(0.015, 0.035, 0.085);
    vec3 darkBlue = vec3(0.03, 0.10, 0.28);
    vec3 sapphireBlue = vec3(0.08, 0.28, 0.72);
    vec3 electricCyan = vec3(0.18, 0.82, 0.98);
    vec3 royalViolet = vec3(0.42, 0.18, 0.88);
    vec3 coreWhite = vec3(0.92, 0.96, 1.0);

    // Apply accent overrides if supplied
    if (uAccentPrimary.a > 0.01) {
        electricCyan = mix(electricCyan, uAccentPrimary.rgb, 0.55);
    }
    if (uAccentSecondary.a > 0.01) {
        royalViolet = mix(royalViolet, uAccentSecondary.rgb, 0.50);
    }

    // Blend base fluid layers
    vec3 col = mix(deepBackground, darkBlue, clamp(f * 1.8, 0.0, 1.0));
    col = mix(col, sapphireBlue, clamp(length(q) * 1.2, 0.0, 1.0));
    col = mix(col, royalViolet, clamp(r.x * 1.4, 0.0, 1.0) * (0.6 + 0.4 * coreGlow));
    col = mix(col, electricCyan, clamp(r.y * 1.6 * f, 0.0, 1.0));

    // Add glowing filaments (silk edges)
    col += electricCyan * totalFilaments * 0.85;
    col += royalViolet * pow(totalFilaments, 2.0) * 0.45;

    // Add luminous volumetric core
    col += mix(sapphireBlue, coreWhite, coreGlow * 0.85) * coreGlow * 1.15;

    // Specular crests along fluid normals
    vec2 normalGrad = vec2(
        fbm(st + vec2(0.01, 0.0) + 3.6 * r) - f,
        fbm(st + vec2(0.0, 0.01) + 3.6 * r) - f
    ) / 0.01;
    float specular = pow(clamp(dot(normalize(vec3(-normalGrad, 1.0)), normalize(vec3(0.3, 0.4, 1.0))), 0.0, 1.0), 12.0);
    col += coreWhite * specular * 0.35 * (f + totalFilaments * 0.5);

    // Global intensity scaling
    col *= uIntensity;

    fragColor = vec4(col, 1.0);
}
