#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 halftoneEffect(float2 position, half4 color, float dotSize, float intensity, float time) {
    float2 cell = floor(position / dotSize);
    float2 center = cell * dotSize + dotSize * 0.5;
    float dist = distance(position, center);

    float luminance = dot(float3(color.rgb), float3(0.299, 0.587, 0.114));
    float radius = (1.0 - luminance) * dotSize * 0.5 * intensity;

    // Subtle time-based pulsing
    radius *= 1.0 + sin(time + cell.x * 0.5) * 0.05;

    half4 halftone;
    if (dist < radius) {
        halftone = half4(0.0, 0.0, 0.0, color.a);
    } else {
        halftone = half4(1.0, 1.0, 1.0, color.a);
    }

    // Mix with original based on intensity
    half4 result = mix(color, halftone, half(intensity));
    return result;
}
