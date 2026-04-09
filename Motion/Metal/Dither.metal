//
//  Dither.metal
//  Motion
//
//  Animated ordered (Bayer 8x8) dithering shader.
//  Converts the source image to black-and-white using a threshold
//  that sweeps in over time, creating a reveal animation.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Classic 8×8 Bayer matrix (normalized 0–1)
constant float bayer8x8[64] = {
     0.0/64.0, 48.0/64.0, 12.0/64.0, 60.0/64.0,  3.0/64.0, 51.0/64.0, 15.0/64.0, 63.0/64.0,
    32.0/64.0, 16.0/64.0, 44.0/64.0, 28.0/64.0, 35.0/64.0, 19.0/64.0, 47.0/64.0, 31.0/64.0,
     8.0/64.0, 56.0/64.0,  4.0/64.0, 52.0/64.0, 11.0/64.0, 59.0/64.0,  7.0/64.0, 55.0/64.0,
    40.0/64.0, 24.0/64.0, 36.0/64.0, 20.0/64.0, 43.0/64.0, 27.0/64.0, 39.0/64.0, 23.0/64.0,
     2.0/64.0, 50.0/64.0, 14.0/64.0, 62.0/64.0,  1.0/64.0, 49.0/64.0, 13.0/64.0, 61.0/64.0,
    34.0/64.0, 18.0/64.0, 46.0/64.0, 30.0/64.0, 33.0/64.0, 17.0/64.0, 45.0/64.0, 29.0/64.0,
    10.0/64.0, 58.0/64.0,  6.0/64.0, 54.0/64.0,  9.0/64.0, 57.0/64.0,  5.0/64.0, 53.0/64.0,
    42.0/64.0, 26.0/64.0, 38.0/64.0, 22.0/64.0, 41.0/64.0, 25.0/64.0, 37.0/64.0, 21.0/64.0
};

// Animated dither with touch-to-reveal
// Parameters: time (dither amount 0→1), pixelScale (cell size),
//             touchX/touchY (drag position), touchActive (1=dragging, 0=not),
//             revealRadius (size of reveal circle)
[[ stitchable ]] half4 ditherEffect(
    float2 position,
    half4 color,
    float time,
    float pixelScale,
    float touchX,
    float touchY,
    float touchActive,
    float revealRadius
) {
    // If fully transparent, pass through
    if (color.a < 0.001h) return color;

    // Luminance (perceptual weights)
    float lum = float(color.r) * 0.299 + float(color.g) * 0.587 + float(color.b) * 0.114;

    // Bayer threshold at this pixel
    int bx = int(position.x / pixelScale) % 8;
    int by = int(position.y / pixelScale) % 8;
    if (bx < 0) bx += 8;
    if (by < 0) by += 8;
    float threshold = bayer8x8[by * 8 + bx];

    // Dithered B&W
    float dithered = (lum + threshold - 0.5) > 0.5 ? 1.0 : 0.0;
    float ditherResult = mix(lum, dithered, time);
    half4 ditherColor = half4(half(ditherResult), half(ditherResult), half(ditherResult), color.a);

    // Touch reveal: blend back to original color near the touch point
    if (touchActive > 0.5) {
        float2 touchPos = float2(touchX, touchY);
        float dist = distance(position, touchPos);

        // Soft circular falloff
        float reveal = 1.0 - smoothstep(revealRadius * 0.3, revealRadius, dist);
        reveal *= touchActive;

        return mix(ditherColor, color, half(reveal));
    }

    return ditherColor;
}
