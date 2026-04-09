#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ── Noise for organic burn edge ──

static float burnHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float burnNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(burnHash(i), burnHash(i + float2(1, 0)), u.x),
               mix(burnHash(i + float2(0, 1)), burnHash(i + float2(1, 1)), u.x), u.y);
}

static float burnFbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < 5; i++) {
        v += a * burnNoise(p);
        p = rot * p * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

// ── Ultra-realistic paper burn (colorEffect) ──
// Spreads from a touch point outward with organic, noisy edges.
// Simulates: charring → ember glow → ash → disappear

[[ stitchable ]] half4 paperBurnEffect(
    float2 position,
    half4 color,
    float2 size,
    float2 touchPoint,
    float burnProgress,   // 0 = no burn, 1 = fully consumed
    float time
) {
    if (color.a < 0.001h) return color;

    float2 uv = position / size;

    // Distance from ignition point (normalized)
    float2 touchUV = touchPoint / size;
    float dist = distance(uv, touchUV);

    // Organic burn boundary using multi-octave noise
    // The noise makes the burn edge irregular, like real fire
    float2 noiseCoord = position * 0.015 + float2(time * 0.8, time * 0.5);
    float edgeNoise = burnFbm(noiseCoord);

    // Second noise layer for finer detail
    float detailNoise = burnNoise(position * 0.04 + float2(time * 1.2, -time * 0.7));

    // Combined noise shapes the burn front
    float noisyDist = dist - (edgeNoise - 0.5) * 0.15 - (detailNoise - 0.5) * 0.06;

    // Burn radius expands with progress
    float burnRadius = burnProgress * 1.2;

    // ── Zones (from center outward): ──
    // 1. Fully burned (transparent)
    // 2. Ash (dark gray, crumbling)
    // 3. Char (black, curling)
    // 4. Ember edge (bright orange/red glow)
    // 5. Heat zone (paper yellowing/browning)
    // 6. Untouched paper

    float zone = noisyDist - burnRadius;

    // Zone 1: Fully consumed — transparent
    if (zone < -0.08) {
        // Wispy ash remnants
        float ash = burnNoise(position * 0.06 + time * 0.3);
        if (ash > 0.7 && zone > -0.12) {
            half gray = half(0.15 + ash * 0.1);
            half ashAlpha = half(smoothstep(-0.12, -0.08, zone)) * 0.3h;
            return half4(gray, gray, gray, ashAlpha);
        }
        return half4(0);
    }

    // Zone 2: Char — blackened, curling paper
    if (zone < -0.02) {
        float charT = smoothstep(-0.08, -0.02, zone);
        float charNoise = burnNoise(position * 0.08);

        half3 charColor = half3(
            half(0.05 + charNoise * 0.08),
            half(0.03 + charNoise * 0.04),
            half(0.02 + charNoise * 0.02)
        );

        // Fading alpha at the edge of char
        half charAlpha = half(mix(0.3, 1.0, charT));
        return half4(charColor * charAlpha, charAlpha);
    }

    // Zone 3: Ember edge — the glowing burn line
    if (zone < 0.025) {
        float emberT = smoothstep(-0.02, 0.025, zone);

        // Animated ember flicker
        float flicker = burnNoise(position * 0.1 + float2(time * 3.0, time * 2.0));
        float flickerIntensity = 0.7 + flicker * 0.6;

        // Ember color: bright orange core → dark red edge
        half3 emberCore = half3(1.0h, 0.65h, 0.1h) * half(flickerIntensity);
        half3 emberEdge = half3(0.8h, 0.2h, 0.05h) * half(flickerIntensity);
        half3 emberColor = mix(emberCore, emberEdge, half(emberT));

        // Glow intensity — brighter in the middle of the ember band
        float glowPeak = 1.0 - abs(emberT - 0.4) * 2.5;
        glowPeak = max(0.0, glowPeak);

        // Mix ember glow over the original color
        half3 result = mix(color.rgb, emberColor, half(glowPeak * 0.9));

        // Add extra brightness (emissive glow)
        result += half3(half(glowPeak * 0.3 * flickerIntensity), half(glowPeak * 0.1 * flickerIntensity), 0);

        return half4(result, color.a);
    }

    // Zone 4: Heat zone — paper browning/yellowing ahead of the fire
    if (zone < 0.1) {
        float heatT = smoothstep(0.025, 0.1, zone);

        // Yellowing → browning gradient
        half3 brownTint = half3(0.6h, 0.35h, 0.15h);
        half3 yellowTint = half3(0.9h, 0.8h, 0.5h);
        half3 heatColor = mix(brownTint, yellowTint, half(heatT));

        // Blend with original paper
        float heatIntensity = (1.0 - heatT) * 0.6;
        half3 result = mix(color.rgb, heatColor, half(heatIntensity));

        return half4(result, color.a);
    }

    // Zone 5: Slight warming — very subtle
    if (zone < 0.18) {
        float warmT = smoothstep(0.1, 0.18, zone);
        float warmAmount = (1.0 - warmT) * 0.15;
        half3 result = color.rgb;
        result.r += half(warmAmount * 0.3);
        result.g -= half(warmAmount * 0.05);
        result.b -= half(warmAmount * 0.1);
        return half4(result, color.a);
    }

    // Untouched paper
    return color;
}
