//
//  GlossySticker.metal
//  Motion
//
//  Realistic glossy vinyl sticker reflection shader.
//  Uses Fresnel edges, specular highlight, sweep band, and rim light
//  driven by gyroscope pitch/roll uniforms.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Attempt Schlick's Fresnel approximation for plastic (IOR ~1.5 → R0 ~0.04)
static half fresnelSchlick(float cosTheta) {
    const half R0 = 0.04h;
    return R0 + (1.0h - R0) * half(pow(1.0 - cosTheta, 5.0));
}

[[ stitchable ]] half4 glossyReflection(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,       // view width, height
    float2 gyro        // x = roll, y = pitch
) {
    // Sample the underlying view
    half4 base = layer.sample(position);

    // Early out for fully transparent pixels (outside rounded rect)
    if (base.a < 0.001h) return base;

    // Normalized UV [0,1]
    float2 uv = position / size;

    // Centered coords [-1, 1]
    float2 centered = uv * 2.0 - 1.0;

    // ── Edge detection via alpha boundary ──
    // Sample neighbors to detect proximity to sticker edge
    float edgeDist = 1.0;
    float step = 1.5; // pixels
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            float2 neighbor = position + float2(float(dx), float(dy)) * step;
            half4 ns = layer.sample(neighbor);
            edgeDist = min(edgeDist, float(ns.a));
        }
    }
    // edgeDist < 1 near transparent edges
    half edgeBright = half(smoothstep(0.95, 0.3, edgeDist)) * 0.12h;

    // ── Fresnel edge glow ──
    float dist = length(centered);
    float cosTheta = saturate(1.0 - dist * 0.7);
    half fresnel = fresnelSchlick(cosTheta);
    half edgeGlow = fresnel * 0.4h + edgeBright;

    // ── Primary specular highlight ──
    // Light position shifts opposite to device tilt
    float2 lightPos = float2(0.5 - gyro.x * 0.4, 0.35 - gyro.y * 0.3);
    float specDist = length(uv - lightPos);
    // Tight Gaussian falloff for point-light look
    half specular = half(exp(-specDist * specDist * 45.0)) * 0.55h;

    // ── Secondary (fill) highlight ──
    float2 fillPos = float2(0.5 - gyro.x * 0.2, 0.6 - gyro.y * 0.15);
    float fillDist = length(uv - fillPos);
    half fill = half(exp(-fillDist * fillDist * 8.0)) * 0.12h;

    // ── Diagonal sweep band ──
    // Rotate UV by -35 degrees, sweep position driven by gyro
    float bandAngle = -0.6109; // -35 deg in radians
    float cosA = cos(bandAngle);
    float sinA = sin(bandAngle);
    float2 rotUV = float2(
        centered.x * cosA - centered.y * sinA,
        centered.x * sinA + centered.y * cosA
    );
    float bandCenter = -(gyro.x + gyro.y) * 0.35;
    float bandDist = abs(rotUV.x - bandCenter);
    // Smooth band with 0.18 half-width
    half band = half(smoothstep(0.22, 0.0, bandDist)) * 0.18h;

    // ── Top rim light ──
    half rim = half(smoothstep(0.3, 0.0, uv.y)) * 0.15h;

    // ── Vinyl glaze base (slight darkening so highlights pop on white) ──
    half glaze = 0.03h;

    // Combine: darken slightly, then add all highlight layers
    half totalHighlight = edgeGlow + specular + fill + band + rim;
    half3 result = base.rgb * (1.0h - glaze) + half3(totalHighlight);

    // Clamp to avoid over-bright
    result = min(result, half3(1.0h));

    return half4(result, base.a);
}
