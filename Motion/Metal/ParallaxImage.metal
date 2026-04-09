#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 parallaxEffect(float2 position, float2 size, float2 tilt, float intensity) {
    float2 center = size * 0.5;
    float2 normalized = (position - center) / (size * 0.5);
    float dist = length(normalized);
    float depth = 1.0 - clamp(dist, 0.0, 1.0);

    float maxShift = 15.0;
    float2 offset = tilt * depth * intensity * maxShift;

    return position + offset;
}
