//
//  LiquidImage.metal
//  Motion
//
//  Liquid/gooey distortion shader for images — organic flowing
//  displacement with layered noise, surface tension, and drip effect.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + float2(1,0)), u.x),
               mix(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x), u.y);
}

static float fbm(float2 p, float time) {
    float v = 0.0, a = 0.5;
    float2 shift = float2(time * 0.3, time * 0.2);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p + shift);
        p *= 2.1;
        a *= 0.5;
        shift *= 1.3;
    }
    return v;
}

[[ stitchable ]] float2 liquidImageEffect(
    float2 position,
    float2 size,
    float time,
    float intensity,
    float touchX,
    float touchY,
    float touchActive
) {
    float2 uv = position / size;

    // ── Global liquid displacement ──

    // Layer 1: Large slow organic blobs
    float n1 = fbm(uv * 3.0, time * 0.5);
    float2 displacement;
    displacement.x = sin(n1 * 6.2831 + time * 1.0) * 30.0;
    displacement.y = cos(n1 * 6.2831 + time * 0.7) * 25.0;

    // Layer 2: Medium gooey waves
    float n2 = fbm(uv * 5.0 + 3.7, time * 0.6);
    displacement.x += sin(uv.y * 7.0 + time * 1.2 + n2 * 4.0) * 15.0;
    displacement.y += sin(uv.x * 5.0 + time * 0.9 + n2 * 3.0) * 12.0;

    // Layer 3: Fine surface ripples
    float n3 = noise(uv * 14.0 + time * 1.2);
    displacement.x += sin(time * 2.0 + uv.y * 12.0) * n3 * 8.0;
    displacement.y += cos(time * 1.8 + uv.x * 10.0) * n3 * 6.0;

    // Layer 4: Gravity drip — heavier at the bottom
    float drip = smoothstep(0.15, 0.85, uv.y);
    displacement.y += drip * sin(time * 0.6 + uv.x * 4.0 + n1 * 2.0) * 18.0;

    // ── Touch interaction — radial push/pull ──
    if (touchActive > 0.01) {
        float2 touchPos = float2(touchX, touchY);
        float2 toTouch = position - touchPos;
        float dist = length(toTouch);
        float radius = 120.0;
        float falloff = 1.0 - smoothstep(0.0, radius, dist);
        float2 dir = normalize(toTouch + 0.001);

        // Swirl around touch point
        float swirl = falloff * touchActive * 40.0;
        float2 swirlDisp;
        swirlDisp.x = -dir.y * swirl + dir.x * swirl * 0.5 * sin(time * 3.0);
        swirlDisp.y = dir.x * swirl + dir.y * swirl * 0.5 * cos(time * 3.0);
        displacement += swirlDisp;

        // Push outward
        displacement += dir * falloff * touchActive * 25.0 * sin(time * 2.5);
    }

    return position + displacement * intensity;
}
