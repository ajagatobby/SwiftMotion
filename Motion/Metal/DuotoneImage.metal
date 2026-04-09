//
//  DuotoneImage.metal
//  Motion
//
//  Maps image luminance to a two-color gradient for duotone effect.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 duotoneEffect(
    float2 position,
    half4 color,
    float3 shadowColor,
    float3 highlightColor,
    float intensity
) {
    if (color.a < 0.001h) return color;

    float lum = dot(float3(color.rgb), float3(0.299, 0.587, 0.114));
    half3 duo = mix(half3(shadowColor), half3(highlightColor), half(lum));
    half3 result = mix(color.rgb, duo, half(intensity));

    return half4(result, color.a);
}
