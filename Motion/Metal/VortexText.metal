//
//  VortexText.metal
//  Motion
//
//  Pixels rotate around a center point.
//  Rotation angle increases for pixels closer to the center.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 vortexEffect(
    float2 position,
    float2 center,
    float time,
    float strength,
    float radius
) {
    float2 delta = position - center;
    float dist = length(delta);

    // Rotation falls off with distance from center
    float normalizedDist = dist / radius;
    float falloff = max(1.0 - normalizedDist, 0.0);
    falloff = falloff * falloff; // quadratic falloff for tighter swirl

    // Angle of rotation: closer pixels rotate more, animated by time
    float angle = falloff * strength * (time * 2.0 + 1.0);

    // Rotate the delta vector
    float cosA = cos(angle);
    float sinA = sin(angle);
    float2 rotated;
    rotated.x = delta.x * cosA - delta.y * sinA;
    rotated.y = delta.x * sinA + delta.y * cosA;

    // Return the new sample position
    return center + rotated;
}
