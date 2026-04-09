//
//  LiquidText.metal
//  Motion
//
//  Liquid/gooey distortion shader — text melts and morphs like thick fluid.
//  Combines layered sine waves with Perlin-like noise for organic movement.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Simple hash-based noise
static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

// Smooth value noise
static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractal Brownian motion for richer organic feel
static float fbm(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 shift = float2(time * 0.3, time * 0.2);

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p + shift);
        p *= 2.1;
        amplitude *= 0.5;
        shift *= 1.3;
    }
    return value;
}

[[ stitchable ]] float2 liquidEffect(
    float2 position,
    float2 size,
    float time,
    float intensity
) {
    // Normalized coordinates
    float2 uv = position / size;

    // Layered organic displacement
    float2 displacement;

    // Layer 1: Large slow blobs
    float n1 = fbm(uv * 3.0, time * 0.6);
    displacement.x = sin(n1 * 6.2831 + time * 1.2) * 25.0;
    displacement.y = cos(n1 * 6.2831 + time * 0.9) * 20.0;

    // Layer 2: Medium gooey waves
    float n2 = fbm(uv * 5.0 + 3.7, time * 0.8);
    displacement.x += sin(uv.y * 8.0 + time * 1.5 + n2 * 4.0) * 12.0;
    displacement.y += sin(uv.x * 6.0 + time * 1.1 + n2 * 3.0) * 10.0;

    // Layer 3: Fine ripples
    float n3 = noise(uv * 12.0 + time * 1.5);
    displacement.x += sin(time * 2.5 + uv.y * 15.0) * n3 * 6.0;
    displacement.y += cos(time * 2.0 + uv.x * 12.0) * n3 * 5.0;

    // Drip/melt effect — stronger displacement toward the bottom
    float meltGradient = smoothstep(0.2, 0.8, uv.y);
    displacement.y += meltGradient * sin(time * 0.8 + uv.x * 5.0) * 15.0;

    return position + displacement * intensity;
}
