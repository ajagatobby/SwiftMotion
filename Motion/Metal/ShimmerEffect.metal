//
//  ShimmerEffect.metal
//  Motion
//
//  Diagonal glossy light-band that sweeps across a view.
//  Used as a colorEffect — multiplies existing colour by a highlight factor.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 shimmerEffect(
    float2 position,
    half4  color,
    float2 size,
    float  time,
    float  speed,        // sweep speed  (e.g. 0.6)
    float  bandWidth     // width of the light band  (e.g. 0.18)
) {
    float2 uv = position / size;

    // Diagonal coordinate — runs from bottom-left to top-right
    float diag = (uv.x + uv.y) * 0.5;

    // Sweep position oscillates 0→1 over time
    float sweep = fract(time * speed);

    // Distance from the sweep centre
    float dist = abs(diag - sweep);
    // Wrap-around (seamless loop)
    dist = min(dist, 1.0 - dist);

    // Smooth band
    float band = smoothstep(bandWidth, 0.0, dist);

    // Highlight — boost brightness in the band
    half highlight = half(1.0 + band * 0.45);

    return half4(color.rgb * highlight, color.a);
}
