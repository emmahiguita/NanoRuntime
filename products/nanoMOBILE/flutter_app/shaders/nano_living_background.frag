#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2 uResolution;
layout(location = 1) uniform float uTime;
layout(location = 2) uniform vec2 uPointer;
layout(location = 3) uniform vec2 uPointerVelocity;
layout(location = 4) uniform float uPointerEnergy;
layout(location = 5) uniform float uSystemEnergy;
layout(location = 6) uniform float uQualityLevel;
layout(location = 7) uniform vec4 uAccentPrimary;
layout(location = 8) uniform vec4 uAccentSecondary;

out vec4 fragColor;

// 2D Rotation Matrix
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
    int octaves = (uQualityLevel < 0.5) ? 2 : (uQualityLevel < 1.5 ? 3 : 4);
    for (int i = 0; i < 4; i++) {
        if (i >= octaves) break;
        v += a * noise(p);
        p = r * p * 2.02 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// Silk Ridge Function: produces ultra-thin luminous filaments & caustics
float silkRidge(vec2 p) {
    float n = sin(p.x * 2.4 + cos(p.y * 1.8)) * cos(p.y * 2.4 + sin(p.x * 1.8));
    return pow(1.0 - abs(n), 4.2);
}

// Height field representing the fluid surface topology
float getFluidHeight(vec2 st, float t, vec2 pointerSt) {
    // 1. Touch & Pointer Ripple Displacement
    vec2 pDelta = st - pointerSt;
    float pDist = length(pDelta);
    float pRipple = sin(pDist * 18.0 - uTime * 4.5) * exp(-pDist * 3.2) * uPointerEnergy * 0.15;

    // Velocity push
    float velPush = dot(uPointerVelocity, normalize(pDelta + 0.001)) * exp(-pDist * 4.0) * 0.05;
    vec2 pos = st + normalize(pDelta + 0.001) * (pRipple + velPush);

    // 2. Multi-tier Domain Warping
    vec2 q = vec2(
        fbm(pos + vec2(0.0, 0.0) + vec2(t * 0.12, -t * 0.08)),
        fbm(pos + vec2(5.2, 1.3) + vec2(-t * 0.10, t * 0.11))
    );

    vec2 r = vec2(
        fbm(pos + 3.0 * q + vec2(1.7, 9.2) + vec2(t * 0.16, -t * 0.14)),
        fbm(pos + 3.0 * q + vec2(8.3, 2.8) + vec2(-t * 0.14, t * 0.18))
    );

    return fbm(pos + 3.4 * r + vec2(0.0, t * 0.06));
}

void main() {
    vec2 uv = FlutterFragCoord().xy;
    vec2 st = (uv - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

    // Dynamic speed influenced by system activity (LLM inference breathing)
    float speedMultiplier = 1.0 + uSystemEnergy * 0.18;
    float t = uTime * 0.20 * speedMultiplier;

    vec2 pointerSt = (uPointer - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

    // 1. Compute Base Height Field
    float h = getFluidHeight(st, t, pointerSt);

    // 2. Dynamic Procedural Normal Map via Spatial Derivatives
    float eps = 0.012;
    float hx = getFluidHeight(st + vec2(eps, 0.0), t, pointerSt);
    float hy = getFluidHeight(st + vec2(0.0, eps), t, pointerSt);
    vec2 grad = vec2(hx - h, hy - h) / eps;
    vec3 normal = normalize(vec3(-grad * 1.5, 1.0));

    // 3. Fine Refraction & Micro-Chromatic Dispersion (~0.8px visual)
    vec2 refrOffset = normal.xy * 0.022;
    float hR = getFluidHeight(st + refrOffset * 1.08, t, pointerSt);
    float hG = getFluidHeight(st + refrOffset, t, pointerSt);
    float hB = getFluidHeight(st + refrOffset * 0.92, t, pointerSt);
    float fluidField = (hR + hG + hB) * 0.3333;

    // 4. Silk Caustics & Tension Filaments
    vec2 causticCoord = st * 3.4 + normal.xy * 2.2;
    float c1 = silkRidge(causticCoord + vec2(t * 0.25, -t * 0.18));
    float c2 = silkRidge(causticCoord * 1.7 - vec2(t * 0.35, t * 0.22));
    float caustics = (c1 * 0.65 + c2 * 0.35);

    // 5. Volumetric Breathing Core Glow
    float coreDist = length(st * vec2(0.85, 1.15) - vec2(0.0, 0.04));
    float corePulse = 0.85 + 0.15 * sin(uTime * 0.75) + uSystemEnergy * 0.12;
    float coreGlow = exp(-coreDist * 2.6) * corePulse;

    // 6. Physically Inspired Fresnel
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float fresnel = pow(1.0 - NdotV, 3.2);

    // 7. Specular Lighting (Ambient Key Light + Secondary Pointer Light)
    vec3 keyLightDir = normalize(vec3(0.35, 0.45, 0.85));
    vec3 pointerLightDir = normalize(vec3(pointerSt - st, 0.45));
    
    vec3 halfVecKey = normalize(keyLightDir + viewDir);
    float specKey = pow(max(dot(normal, halfVecKey), 0.0), 16.0);

    vec3 halfVecPtr = normalize(pointerLightDir + viewDir);
    float pDist = length(pointerSt - st);
    float ptrLightAtten = exp(-pDist * 3.0) * (0.4 + uPointerEnergy * 0.6);
    float specPtr = pow(max(dot(normal, halfVecPtr), 0.0), 22.0) * ptrLightAtten;

    // 8. Color Harmony (Deep Velvet, Sapphire, Cyan, Royal Violet, Core White)
    vec3 deepBackground = vec3(0.012, 0.028, 0.068);
    vec3 darkSapphire   = vec3(0.035, 0.11, 0.30);
    vec3 cobaltBlue     = vec3(0.07, 0.26, 0.70);
    vec3 electricCyan   = vec3(0.18, 0.82, 0.98);
    vec3 royalViolet    = vec3(0.40, 0.16, 0.86);
    vec3 coreWhite      = vec3(0.92, 0.96, 1.0);

    // Accent override integration
    if (uAccentPrimary.a > 0.01) {
        electricCyan = mix(electricCyan, uAccentPrimary.rgb, 0.50);
    }
    if (uAccentSecondary.a > 0.01) {
        royalViolet = mix(royalViolet, uAccentSecondary.rgb, 0.45);
    }

    // Compose fluid layers with depth
    vec3 col = mix(deepBackground, darkSapphire, clamp(fluidField * 1.7, 0.0, 1.0));
    col = mix(col, cobaltBlue, clamp(hG * 1.3, 0.0, 1.0));
    col = mix(col, royalViolet, clamp(hR * 1.5, 0.0, 1.0) * (0.65 + 0.35 * coreGlow));
    col = mix(col, electricCyan, clamp(hB * 1.8 * fluidField, 0.0, 1.0));

    // Add silk filaments & caustics (2-6% subtle brightness)
    col += electricCyan * caustics * 0.75;
    col += royalViolet * pow(caustics, 2.0) * 0.40;

    // Add luminous breathing core
    col += mix(cobaltBlue, coreWhite, coreGlow * 0.82) * coreGlow * 1.10;

    // Add Fresnel edge luminosity
    col += mix(electricCyan, royalViolet, 0.45) * fresnel * 0.55;

    // Add Specular reflections
    col += coreWhite * (specKey * 0.35 + specPtr * 0.45) * (fluidField + caustics * 0.5);

    // Subtle pointer proximity glow
    col += electricCyan * ptrLightAtten * 0.15;

    fragColor = vec4(col, 1.0);
}
