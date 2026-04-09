//
//  NoiseDissolve.metal
//  Motion
//
//  Image dissolves into noise/particles based on an animated threshold.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

[[ stitchable ]] half4 noiseDissolveEffect(
    float2 position,
    half4 color,
    float threshold,
    float edgeWidth
) {
    if (color.a < 0.001h) return color;

    float n = hash(floor(position * 0.5));

    if (n < threshold - edgeWidth) {
        return half4(0);
    }

    if (n < threshold) {
        return half4(1.0h, 0.6h, 0.2h, color.a);
    }

    return color;
}
