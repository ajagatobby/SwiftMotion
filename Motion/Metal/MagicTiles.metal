//
//  MagicTiles.metal
//  Motion
//
//  Tap ripple effect + tile glow for Magic Tiles game.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Ripple effect on tap — expands outward from tap position
[[ stitchable ]] half4 tileRipple(
    float2 position,
    half4 color,
    float2 tapPos,
    float rippleTime,    // 0 = just tapped, grows over time
    float intensity      // 0-1
) {
    if (color.a < 0.001h || intensity < 0.001) return color;

    float dist = distance(position, tapPos);
    float rippleRadius = rippleTime * 400.0;
    float rippleWidth = 40.0;

    float ring = 1.0 - abs(dist - rippleRadius) / rippleWidth;
    ring = max(ring, 0.0);
    ring *= intensity;
    ring *= smoothstep(rippleRadius + rippleWidth, rippleRadius, dist); // fade outer

    color.rgb += half3(half(ring * 0.3));

    return color;
}
