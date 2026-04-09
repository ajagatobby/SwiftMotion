#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 chromeEffect(float2 position, half4 color, float2 size, float2 angle, float time) {
    if (color.a < 0.001h) {
        return color;
    }

    // Simulated environment reflection based on position and angle
    float reflection = sin(position.x / size.x * 3.14159 * 2.0 + angle.x * 3.0 + time * 0.5);
    reflection += cos(position.y / size.y * 3.14159 + angle.y * 2.0) * 0.5;

    // Map to 0-1 range
    float t = reflection * 0.5 + 0.5;

    // Metallic color ramp
    half3 darkChrome = half3(0.15h, 0.15h, 0.18h);
    half3 brightChrome = half3(0.95h, 0.95h, 1.0h);
    half3 chrome = mix(darkChrome, brightChrome, half(t));

    return half4(chrome * color.a, color.a);
}
