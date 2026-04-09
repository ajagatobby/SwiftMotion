//
//  MorphImage.metal
//  Motion
//
//  Funhouse mirror distortion effect — pixels near touch point
//  get pushed away radially with a bulge/pinch effect.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 morphEffect(
    float2 position,
    float2 touchPos,
    float strength,
    float radius
) {
    float2 delta = position - touchPos;
    float dist = length(delta);

    if (dist < radius && dist > 0.001) {
        float factor = pow(dist / radius, 2.0);
        return touchPos + normalize(delta) * factor * radius * strength + delta * (1.0 - strength);
    }

    return position;
}
