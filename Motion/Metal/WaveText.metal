//
//  WaveText.metal
//  Motion
//
//  Sine wave distortion that flows through text.
//  Layered sine waves at different frequencies and phases for rich movement.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] float2 waveEffect(
    float2 position,
    float2 size,
    float time,
    float intensity,
    float frequency
) {
    float2 uv = position / size;

    float2 displacement = float2(0.0);

    // Layer 1: Primary horizontal wave
    displacement.y += sin(uv.x * frequency * 6.0 + time * 2.5) * 18.0;
    displacement.x += cos(uv.y * frequency * 4.0 + time * 1.8) * 10.0;

    // Layer 2: Secondary wave at different phase
    displacement.y += sin(uv.x * frequency * 10.0 - time * 3.2 + 1.5) * 8.0;
    displacement.x += cos(uv.y * frequency * 8.0 - time * 2.1 + 2.0) * 6.0;

    // Layer 3: Fine ripple
    displacement.y += sin(uv.x * frequency * 18.0 + time * 4.5 + uv.y * 3.0) * 4.0;
    displacement.x += cos(uv.y * frequency * 14.0 + time * 3.8 + uv.x * 2.0) * 3.0;

    // Layer 4: Slow undulation for organic feel
    displacement.y += sin(time * 0.7 + uv.x * 2.0) * 6.0;
    displacement.x += cos(time * 0.5 + uv.y * 2.5) * 5.0;

    return position + displacement * intensity;
}
