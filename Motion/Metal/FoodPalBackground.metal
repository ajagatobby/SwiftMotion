//
//  FoodPalBackground.metal
//  Motion
//
//  Warm food-themed animated gradient — golden amber, fresh green, soft coral aurora.
//  Visibly flowing blobs with swirling motion and pulsing glow.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ── helpers ──────────────────────────────────────────────────────────

static float fp_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float fp_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = fp_hash(i);
    float b = fp_hash(i + float2(1, 0));
    float c = fp_hash(i + float2(0, 1));
    float d = fp_hash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fp_fbm(float2 p) {
    float v = 0.0, a = 0.5;
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += a * fp_noise(p);
        p = rot * p * 2.1;
        a *= 0.5;
    }
    return v;
}

// ── main shader ──────────────────────────────────────────────────────

[[ stitchable ]] half4 foodPalBackground(
    float2 position,
    half4  color,
    float2 size,
    float  time,
    float  phase          // 0‥1  drives palette shift across phases
) {
    float2 uv = position / size;

    // Swirl — rotate uv around center over time for organic motion
    float2 centered = uv - 0.5;
    float angle = time * 0.06;
    float ca = cos(angle), sa = sin(angle);
    float2 swirled = float2(centered.x * ca - centered.y * sa,
                            centered.x * sa + centered.y * ca) + 0.5;

    // Three flowing noise layers — faster, more visible movement
    float n1 = fp_fbm(swirled * 3.0 + float2(time * 0.25, time * 0.15));
    float n2 = fp_fbm(uv * 2.5 + float2(-time * 0.18, time * 0.12) + 5.0);
    float n3 = fp_fbm(uv * 4.0 + float2(time * 0.10, -time * 0.20) + 10.0);

    // Warped layer — domain warping for more organic feel
    float warp = fp_fbm(uv * 2.0 + float2(n1 * 1.5, n2 * 1.5));

    // ── palette — deep, rich tones for contrast with white text ──
    half3 c1 = half3(0.65h, 0.45h, 0.15h);   // Deep amber / burnt orange
    half3 c2 = half3(0.20h, 0.45h, 0.20h);   // Forest green
    half3 c3 = half3(0.60h, 0.28h, 0.18h);   // Deep terracotta
    half3 c4 = half3(0.22h, 0.20h, 0.18h);   // Dark warm base
    half3 c5 = half3(0.50h, 0.30h, 0.12h);   // Rich brown

    // Phase-driven mixing
    float ph = clamp(phase, 0.0, 1.0);

    half3 col = c4;
    col = mix(col, c1, half(smoothstep(0.20, 0.60, n1) * (0.55 + 0.3 * ph)));
    col = mix(col, c2, half(smoothstep(0.25, 0.55, n2) * (0.40 + 0.25 * ph)));
    col = mix(col, c3, half(smoothstep(0.30, 0.60, n3) * (0.30 + 0.2 * ph)));
    col = mix(col, c5, half(smoothstep(0.40, 0.70, warp) * (0.25 + 0.15 * ph)));

    // Pulsing glow — warm breathing light
    float2 glowCenter = float2(0.5 + 0.2 * sin(time * 0.3),
                               0.5 + 0.2 * cos(time * 0.25));
    float glowDist = length(uv - glowCenter);
    float glow = exp(-glowDist * glowDist * 6.0) * (0.10 + 0.06 * sin(time * 0.8));
    col += half(glow) * half3(0.6h, 0.4h, 0.2h);

    // Second glow — green accent
    float2 glow2Center = float2(0.5 - 0.25 * sin(time * 0.22 + 2.0),
                                0.5 - 0.15 * cos(time * 0.35 + 1.0));
    float glow2Dist = length(uv - glow2Center);
    float glow2 = exp(-glow2Dist * glow2Dist * 10.0) * (0.08 + 0.04 * sin(time * 1.1));
    col += half(glow2) * half3(0.2h, 0.5h, 0.2h);

    // Radial vignette — darken edges more
    float vignette = 1.0 - dot(centered, centered) * 1.0;
    col *= half(vignette);

    // Vertical gradient — darker at bottom
    col *= half(0.85 + (1.0 - uv.y) * 0.15);

    return half4(col, 1.0h);
}
