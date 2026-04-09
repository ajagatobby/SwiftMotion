//
//  MagnetText.metal
//  Motion
//
//  Pixels attract toward or repel from a touch point.
//  Uses inverse-square-ish falloff for a magnetic feel.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 magnetEffect(
    float2 position,
    float2 touchPos,
    float strength,
    float radius
) {
    float2 delta = position - touchPos;
    float dist = length(delta);

    // Avoid division by zero
    if (dist < 0.001) {
        return position;
    }

    // Inverse-square-ish falloff, clamped within radius
    float normalizedDist = dist / radius;
    float falloff = 1.0 / (1.0 + normalizedDist * normalizedDist * 4.0);

    // Fade to zero at radius edge
    falloff *= smoothstep(1.2, 0.0, normalizedDist);

    // Positive strength = attract (move toward touch), negative = repel
    float2 direction = normalize(delta);
    float2 offset = direction * falloff * strength * radius * 0.5;

    return position - offset;
}
