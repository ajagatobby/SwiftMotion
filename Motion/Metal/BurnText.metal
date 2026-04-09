#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

[[ stitchable ]] half4 burnEffect(float2 position, half4 color, float touchX, float touchY, float burnRadius, float time) {
    if (color.a < 0.001h) {
        return color;
    }

    float2 touchPoint = float2(touchX, touchY);
    float dist = distance(position, touchPoint);

    // Animated noise
    float2 noisePos = position * 0.05 + float2(time * 0.3, time * 0.2);
    float noise = hash(floor(noisePos));
    float noise2 = hash(floor(noisePos * 2.0));
    float combinedNoise = mix(noise, noise2, 0.5);

    // Burn gradient based on distance from touch
    float burnEdge = burnRadius;
    float burnGradient = 1.0 - smoothstep(0.0, burnEdge, dist);

    // Compare noise to burn gradient to decide dissolve
    float dissolveThreshold = burnGradient * 1.2;
    float dissolve = step(combinedNoise, dissolveThreshold);

    // Ember edge glow
    float edgeWidth = 0.15;
    float edgeFactor = smoothstep(dissolveThreshold - edgeWidth, dissolveThreshold, combinedNoise) *
                       step(combinedNoise, dissolveThreshold + 0.01);

    if (dissolve > 0.5 && edgeFactor < 0.1) {
        // Fully dissolved
        return half4(0.0h, 0.0h, 0.0h, 0.0h);
    }

    if (edgeFactor > 0.1) {
        // Ember glow at dissolve edge
        half4 ember = half4(1.0h, 0.3h, 0.0h, color.a);
        return mix(color, ember, half(edgeFactor));
    }

    return color;
}
