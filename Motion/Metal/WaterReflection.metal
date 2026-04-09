#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 waterReflection(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float intensity,
    float touchX,
    float touchY,
    float touchActive
) {
    float midY = size.y * 0.5;

    if (position.y < midY) {
        // Top half — apply touch ripple only
        if (touchActive > 0.01) {
            float2 touchPos = float2(touchX, touchY);
            float dist = distance(position, touchPos);
            float ripple = sin(dist * 0.3 - time * 8.0) * exp(-dist * 0.015) * touchActive * 3.0;
            float2 ripplePos = position + normalize(position - touchPos + 0.001) * ripple;
            return layer.sample(ripplePos);
        }
        return layer.sample(position);
    }

    // Flip y coordinate for reflection
    float flippedY = midY - (position.y - midY);

    // Base ripple waves
    float frequency = 30.0;
    float amplitude = 3.0;
    float displacement = sin(position.y * frequency * 0.05 + time * 3.0) * amplitude * intensity;
    displacement += sin(position.y * frequency * 0.08 + time * 2.0) * amplitude * 0.5 * intensity;

    // Touch-driven ripple in reflection
    if (touchActive > 0.01) {
        float2 touchPos = float2(touchX, touchY);
        float2 reflectedTouchPos = float2(touchX, midY - (touchY - midY));
        float dist = distance(position, reflectedTouchPos);
        float ripple = sin(dist * 0.25 - time * 6.0) * exp(-dist * 0.01) * touchActive * 8.0;
        displacement += ripple;
    }

    float2 samplePos = float2(position.x + displacement, flippedY);
    samplePos.x = clamp(samplePos.x, 0.0, size.x);
    samplePos.y = clamp(samplePos.y, 0.0, midY);

    half4 col = layer.sample(samplePos);

    // Fade toward bottom
    float fade = (position.y - midY) / midY;
    col.rgb *= half3(0.6h, 0.65h, 0.8h) * half(1.0 - fade * 0.5);
    col.a *= half(1.0 - fade * 0.4);

    return col;
}
