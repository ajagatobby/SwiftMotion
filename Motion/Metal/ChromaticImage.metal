#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 chromaticEffect(float2 position, SwiftUI::Layer layer, float2 offset, float intensity) {
    float2 rPos = position + offset * intensity;
    float2 gPos = position;
    float2 bPos = position - offset * intensity;

    half4 r = layer.sample(rPos);
    half4 g = layer.sample(gPos);
    half4 b = layer.sample(bPos);

    return half4(r.r, g.g, b.b, max(r.a, max(g.a, b.a)));
}
