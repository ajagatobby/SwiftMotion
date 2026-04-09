//
//  GlitchText.metal
//  Motion
//
//  RGB split, horizontal slice displacement, and scanlines.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

[[ stitchable ]] half4 glitchEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float intensity
) {
    float2 uv = position / size;

    // Horizontal slice displacement — random rows shift left/right
    float sliceRow = floor(uv.y * 30.0);
    float sliceNoise = hash(float2(sliceRow, floor(time * 8.0)));
    float sliceShift = 0.0;
    if (sliceNoise > (1.0 - intensity * 0.4)) {
        sliceShift = (hash(float2(sliceRow, floor(time * 12.0))) - 0.5) * intensity * 60.0;
    }

    // RGB channel split offsets
    float rgbSplit = intensity * 8.0;
    float2 rPos = float2(position.x + sliceShift + rgbSplit, position.y);
    float2 gPos = float2(position.x + sliceShift, position.y);
    float2 bPos = float2(position.x + sliceShift - rgbSplit, position.y);

    half4 rSample = layer.sample(rPos);
    half4 gSample = layer.sample(gPos);
    half4 bSample = layer.sample(bPos);

    half4 result = half4(rSample.r, gSample.g, bSample.b, max(max(rSample.a, gSample.a), bSample.a));

    // Scanlines
    float scanline = sin(position.y * 3.0) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, intensity * 0.3);
    result.rgb *= half(scanline);

    // Random brightness flicker
    float flicker = 1.0 + (hash(float2(floor(time * 15.0), 0.0)) - 0.5) * intensity * 0.3;
    result.rgb *= half(flicker);

    return result;
}
