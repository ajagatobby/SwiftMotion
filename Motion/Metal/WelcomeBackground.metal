//
//  WelcomeBackground.metal
//  Motion
//
//  Animated gradient mesh background — flowing aurora-like color bands.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = fract(sin(dot(i, float2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1,0), float2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0,1), float2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1,1), float2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
    return v;
}

[[ stitchable ]] half4 welcomeBackground(
    float2 position,
    half4 color,
    float2 size,
    float time
) {
    float2 uv = position / size;

    // Flowing noise field
    float n1 = fbm(uv * 3.0 + float2(time * 0.08, time * 0.05));
    float n2 = fbm(uv * 2.0 + float2(-time * 0.06, time * 0.04) + 5.0);
    float n3 = fbm(uv * 4.0 + float2(time * 0.03, -time * 0.07) + 10.0);

    // Color palette — soft muted tones
    half3 c1 = half3(0.95h, 0.92h, 0.88h); // warm cream
    half3 c2 = half3(0.88h, 0.90h, 0.95h); // cool blue-gray
    half3 c3 = half3(0.92h, 0.88h, 0.93h); // soft lavender
    half3 c4 = half3(0.90h, 0.93h, 0.90h); // pale sage

    half3 col = c1;
    col = mix(col, c2, half(smoothstep(0.3, 0.7, n1)));
    col = mix(col, c3, half(smoothstep(0.4, 0.6, n2) * 0.5));
    col = mix(col, c4, half(smoothstep(0.35, 0.65, n3) * 0.3));

    // Subtle gradient overlay — darker at top, lighter at bottom
    col *= half(0.92 + uv.y * 0.08);

    return half4(col, 1.0h);
}
