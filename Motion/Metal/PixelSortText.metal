#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 pixelSortEffect(float2 position, SwiftUI::Layer layer, float2 size, float intensity, float time) {
    // Sample current pixel to get luminance
    half4 current = layer.sample(position);
    float luminance = float(current.r) * 0.299 + float(current.g) * 0.587 + float(current.b) * 0.114;

    // Offset based on luminance and intensity
    float offset = luminance * intensity * 80.0;
    offset += sin(position.y * 0.1 + time) * intensity * 5.0;

    // Sample from offset position
    float2 samplePos = float2(position.x + offset, position.y);

    // Clamp to bounds
    samplePos.x = clamp(samplePos.x, 0.0, size.x);

    half4 result = layer.sample(samplePos);
    return result;
}
