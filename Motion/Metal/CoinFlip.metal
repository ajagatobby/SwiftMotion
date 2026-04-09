//
//  CoinFlip.metal
//  Motion
//
//  3D coin flip shader using layerEffect.
//  Perspective Y-axis rotation + metallic lighting overlay.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 coinFlip3D(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float  angle,
    float  focalLen,
    float  time,
    float2 lightXY
) {
    // Center of the view
    float2 center = size * 0.5;

    // Pixel offset from center
    float2 offset = position - center;

    // Normalize to [-1, 1] using half the smallest dimension
    float halfSize = min(size.x, size.y) * 0.5;
    float2 uv = offset / halfSize;

    // Y-axis rotation
    float c = cos(angle);
    float s = sin(angle);

    // Apply rotation to x, producing x' and z'
    float rotX = uv.x * c;
    float rotZ = -uv.x * s;

    // Perspective: camera at z = -focalLen looking toward z = 0
    float perspDenom = focalLen - rotZ;
    if (perspDenom <= 0.0) return half4(0.0);
    float perspScale = focalLen / perspDenom;

    // Source UV after inverse perspective
    float srcX = rotX / perspScale;
    float srcY = uv.y / perspScale;

    // Coin radius in normalized space (slightly less than 1.0 to give padding)
    float coinR = 0.92;
    float dist = length(float2(srcX, srcY));

    // Outside the coin — check for edge strip
    if (dist > coinR) {
        // Coin edge (visible thickness when rotated)
        float edgeThick = 0.025 * abs(s);
        float edgeDist = dist - coinR;
        if (edgeDist < edgeThick) {
            float edgeAlpha = 1.0 - smoothstep(0.0, edgeThick, edgeDist);
            // Dark gold edge
            half3 edgeBase = half3(0.55, 0.40, 0.15);
            // Light the edge based on angle
            float edgeLight = 0.5 + 0.5 * max(dot(normalize(float3(s, 0.0, c)), normalize(float3(lightXY, 1.0))), 0.0);
            return half4(edgeBase * half(edgeLight) * half(edgeAlpha), half(edgeAlpha));
        }
        return half4(0.0);
    }

    // Determine which face is showing
    bool frontFace = c >= 0.0;

    // Map source UV back to pixel coordinates
    float2 srcPixel;
    if (frontFace) {
        srcPixel = float2(srcX, srcY) * halfSize + center;
    } else {
        // Mirror X for back face
        srcPixel = float2(-srcX, srcY) * halfSize + center;
    }

    // Sample the view content
    half4 base = layer.sample(srcPixel);

    // If the sampled pixel is transparent, return transparent
    if (base.a < 0.01h) return half4(0.0);

    // ── Lighting (additive overlay — preserves base art colors) ──

    // Surface normal for the rotated coin face
    float3 normal = normalize(float3(s, 0.0, abs(c)));

    // Add slight convexity (dome shape)
    float3 bump = normalize(float3(srcX * 0.12, srcY * 0.12, 1.0));
    normal = normalize(normal + bump * 0.15);

    float3 lightDir = normalize(float3(lightXY.x, lightXY.y, 1.0));
    float3 viewDir  = float3(0.0, 0.0, 1.0);
    float3 halfVec  = normalize(lightDir + viewDir);

    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotH = max(dot(normal, halfVec), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);

    // Specular highlight (gold-tinted)
    half3 specColor = half3(1.0, 0.9, 0.6);
    half spec = half(pow(NdotH, 48.0)) * 0.7h;

    // Fresnel rim glow
    float rim = pow(1.0 - NdotV, 4.0);
    half3 rimColor = half3(1.0, 0.85, 0.5) * half(rim) * 0.3h;

    // Diffuse shading — gentle, doesn't darken much
    half diffuse = half(0.7 + 0.3 * NdotL);

    // Subtle lathe/radial lines
    float radAngle = atan2(srcY, srcX);
    float lathe = sin(radAngle * 80.0 + dist * 200.0) * 0.5 + 0.5;
    half latheHighlight = half(lathe * NdotL * 0.04);

    // Subtle environment shimmer
    float shimmer = sin(normal.x * 5.0 + time * 0.8) * 0.5 + 0.5;
    half envShimmer = half(shimmer * 0.03);

    // Bevel darkening at coin edge
    half bevel = half(smoothstep(coinR, coinR - 0.08, dist));

    // Compose: base color × gentle diffuse + additive highlights
    half3 result = base.rgb * diffuse * bevel;
    result += specColor * spec;
    result += rimColor;
    result += half3(latheHighlight) * half3(1.0, 0.9, 0.65);
    result += half3(envShimmer) * half3(1.0, 0.9, 0.6);

    // Perspective brightness
    half perspBright = half(0.9 + 0.1 * clamp(perspScale, 0.5, 2.0));
    result *= perspBright;

    result = min(result, half3(1.0h));

    // Soft edge antialiasing
    half alpha = base.a * half(smoothstep(coinR, coinR - 0.015, dist));

    return half4(result * alpha, alpha);
}
