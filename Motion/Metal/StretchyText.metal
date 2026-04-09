//
//  StretchyText.metal
//  Motion
//
//  Elastic rubber-band distortion shader for text.
//  Pulls pixels toward a touch point with smooth falloff.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 stretchEffect(
    float2 position,
    float2 touchPos,
    float strength,
    float radius
) {
    float2 delta = position - touchPos;
    float dist = length(delta);

    // Smooth Gaussian-like falloff
    float falloff = exp(-0.5 * (dist * dist) / (radius * radius));

    // Pull pixels toward the touch point
    float2 offset = delta * falloff * strength;

    return position - offset;
}
