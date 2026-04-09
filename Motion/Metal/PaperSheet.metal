//
//  PaperSheet.metal
//  Motion
//
//  Ultra-realistic paper sheet shader.
//  Procedural fiber texture, grain, color variation, edge curl distortion,
//  page-turn curl, and gyroscope-driven diffuse lighting.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ── Noise Primitives ──

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash(i), hash(i + float2(1,0)), u.x),
               mix(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x), u.y);
}

static float fbm(float2 p, int oct) {
    float v = 0.0, a = 0.5;
    float2x2 rot = float2x2(0.8, 0.6, -0.6, 0.8);
    for (int i = 0; i < oct; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + 100.0;
        a *= 0.5;
    }
    return v;
}

// ── Paper Texture (colorEffect) ──
// Adds grain, fiber, and color variation to the paper surface.
// Uniforms: size, gyro (roll, pitch), time

[[ stitchable ]] half4 paperTexture(
    float2 position,
    half4 color,
    float2 size,
    float2 gyro,
    float time
) {
    if (color.a < 0.001h) return color;

    float2 uv = position / size;

    // ── Base paper color: warm off-white with radial vignette ──
    half3 paperBase = half3(0.988h, 0.980h, 0.960h); // slightly cream
    float vigDist = length(uv - 0.5) * 1.3;
    half vignette = half(smoothstep(0.2, 0.9, vigDist)) * 0.04h;
    paperBase -= half3(vignette * 0.3h, vignette * 0.15h, vignette * 0.0h);

    // ── Fiber texture: anisotropic stretched noise ──
    // Stretch horizontally to mimic machine-direction fibers
    float2 fiberUV = float2(position.x * 0.8, position.y * 1.6);
    float fiber = fbm(fiberUV * 0.08, 4);
    // Second layer rotated 60 degrees for cross-fibers
    float2 crossUV = float2(
        position.x * 0.866 - position.y * 0.5,
        position.x * 0.5 + position.y * 0.866
    );
    float crossFiber = fbm(crossUV * 0.06, 3);
    float fiberBlend = fiber * 0.6 + crossFiber * 0.4;
    half fiberValue = half((fiberBlend - 0.5) * 0.08);

    // ── Fine grain: high-frequency noise for surface texture ──
    float grain = noise(position * 0.6) * 0.5
                + noise(position * 1.2) * 0.3
                + noise(position * 2.5) * 0.2;
    half grainValue = half((grain - 0.5) * 0.06);

    // ── Micro-specks: tiny dark imperfections ──
    float speck = noise(position * 0.3 + 42.0);
    half speckValue = speck > 0.88 ? -0.03h : 0.0h;

    // ── Subtle wrinkle lines ──
    float wrinkle1 = sin(uv.x * 180.0 + fbm(uv * 8.0, 3) * 12.0) * 0.5 + 0.5;
    float wrinkle2 = sin(uv.y * 140.0 + fbm(uv * 6.0 + 50.0, 3) * 10.0) * 0.5 + 0.5;
    float wrinkle = wrinkle1 * wrinkle2;
    half wrinkleValue = half(smoothstep(0.85, 1.0, wrinkle) * 0.012);

    // ── Gyroscope-driven diffuse lighting (very subtle, matte) ──
    // Paper is matte so lighting is a broad gentle gradient, not specular
    float lightX = 0.5 - gyro.x * 0.25;
    float lightY = 0.4 - gyro.y * 0.2;
    float lightDist = length(uv - float2(lightX, lightY));
    half diffuse = half(exp(-lightDist * lightDist * 1.8)) * 0.03h;

    // ── Edge darkening (contact shadow effect at paper borders) ──
    float edgeX = min(uv.x, 1.0 - uv.x);
    float edgeY = min(uv.y, 1.0 - uv.y);
    float edgeDist = min(edgeX, edgeY);
    half edgeDarken = half(smoothstep(0.06, 0.0, edgeDist)) * 0.06h;

    // ── Compose ──
    half3 result = paperBase + half3(fiberValue) + half3(grainValue)
                 + half3(speckValue) + half3(wrinkleValue) + half3(diffuse)
                 - half3(edgeDarken);

    return half4(result * color.a, color.a);
}


// ── Paper Press Effect (colorEffect) ──
// A soft shadow/light wave that radiates from a touch point.
// No pixel displacement — only brightness changes, so text stays crisp.
// Simulates the paper surface bending slightly under a finger press.

[[ stitchable ]] half4 paperPress(
    float2 position,
    half4 color,
    float2 size,
    float2 touchPoint,
    float time,
    float intensity
) {
    if (color.a < 0.001h || intensity < 0.001) return color;

    float2 delta = position - touchPoint;
    float dist = length(delta);

    // Expanding ring of light/shadow
    float speed = 280.0;
    float waveFront = time * speed;
    float distFromFront = abs(dist - waveFront);

    // Ring envelope — visible only near the wave front
    float ring = exp(-distFromFront * distFromFront * 0.003) * intensity;

    // Fade with distance from touch
    ring *= exp(-dist * 0.005);

    // Light/shadow pattern: bright on outer edge, dark on inner
    float wave = sin(dist * 0.08 - time * 8.0);
    half shadow = half(wave * ring * 0.06);

    // Press dimple — dark spot at touch point that fades out
    float dimple = exp(-dist * dist * 0.0003) * intensity * max(0.0, 1.0 - time * 2.0);
    half dimpleShadow = half(dimple * 0.05);

    // Apply — darken for shadow, brighten for highlight
    half3 result = color.rgb + half3(shadow) - half3(dimpleShadow);

    return half4(result, color.a);
}


// ── Page Curl Distortion (layerEffect) ──
// Creates a cylindrical page curl driven by a drag position.
// The curl wraps pixels around a virtual cylinder.
// Uniforms: size, curlX (0..1, horizontal position of curl axis),
//           curlRadius, curlAngle, time

[[ stitchable ]] half4 paperCurl(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float curlX,      // normalized x position of curl line (0=left, 1=right)
    float curlRadius, // radius of curl cylinder in pixels
    float curlAmount, // 0 = flat, 1 = fully curled
    float time
) {
    half4 original = layer.sample(position);
    float2 uv = position / size;

    // Curl line position in pixels
    float lineX = curlX * size.x;

    if (curlAmount < 0.001) return original;

    // Distance from the curl line
    float dx = position.x - lineX;

    // ── Region 1: Flat part (left of curl line) ──
    if (dx < 0.0) {
        // Flat — but add a subtle shadow near the curl line
        float shadowDist = abs(dx);
        half shadow = half(smoothstep(curlRadius * 1.5, 0.0, shadowDist)) * 0.25h * half(curlAmount);
        return half4(original.rgb * (1.0h - shadow), original.a);
    }

    // ── Region 2: The curl itself ──
    float maxCurl = curlRadius * 3.14159 * curlAmount;

    if (dx < maxCurl) {
        // Map dx to angle around cylinder
        float angle = dx / curlRadius;
        float mappedAngle = angle * curlAmount;

        // Position on cylinder surface
        float cylX = lineX + sin(mappedAngle) * curlRadius;
        float cylZ = (1.0 - cos(mappedAngle)) * curlRadius;

        // Are we seeing the front or back of the paper?
        bool isFront = mappedAngle < 3.14159;

        // Sample the original position (unwrapped)
        float sourceX = lineX + dx;
        float2 samplePos = float2(sourceX, position.y);

        // Clamp to bounds
        samplePos.x = clamp(samplePos.x, 0.0, size.x);
        samplePos.y = clamp(samplePos.y, 0.0, size.y);

        half4 sampled = layer.sample(samplePos);

        if (isFront) {
            // Front face: add curvature shading
            float nDotL = cos(mappedAngle * 0.5);
            half shade = half(mix(0.85, 1.0, nDotL));
            return half4(sampled.rgb * shade, sampled.a);
        } else {
            // Back face: darker, slightly blue-tinted (paper back)
            half3 backColor = half3(0.92h, 0.91h, 0.90h);
            // Add fiber texture to back
            float backFiber = fbm(samplePos * 0.05, 3);
            backColor += half3(half((backFiber - 0.5) * 0.03));

            float backShade = 0.7 + 0.3 * cos(mappedAngle - 3.14159);
            return half4(backColor * half(backShade), sampled.a);
        }
    }

    // ── Region 3: Beyond the curl (hidden) ──
    return half4(0);
}


// ── Corner Peel Effect (layerEffect) ──
// Peels from bottom-right corner based on drag distance.
// Uniforms: size, peelAmount (0..1), peelAngle

[[ stitchable ]] half4 paperCornerPeel(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float peelAmount,  // 0 = flat, 1 = fully peeled
    float peelAngle    // angle of peel direction in radians
) {
    half4 original = layer.sample(position);
    if (peelAmount < 0.001) return original;

    float2 uv = position / size;

    // Peel origin: bottom-right corner
    float2 corner = float2(1.0, 1.0);
    float2 toPos = uv - corner;

    // Rotate into peel space
    float ca = cos(peelAngle);
    float sa = sin(peelAngle);
    float peelDist = toPos.x * ca + toPos.y * sa;

    // Peel threshold moves inward as peelAmount increases
    float threshold = -peelAmount * 0.7;

    if (peelDist > threshold) {
        // In the peeled region
        float foldDist = peelDist - threshold;
        float radius = 0.04 + peelAmount * 0.02;

        if (foldDist < radius * 3.14159) {
            // On the curl
            float angle = foldDist / radius;
            bool showBack = angle > 3.14159 * 0.5;

            if (showBack) {
                // Show paper back
                half3 backColor = half3(0.93h, 0.92h, 0.91h);
                float shade = 0.8 + 0.2 * cos(angle - 3.14159);
                return half4(backColor * half(shade), original.a);
            } else {
                // Curving front face — darken based on curl
                float shade = 0.9 + 0.1 * cos(angle);
                return half4(original.rgb * half(shade), original.a);
            }
        }

        // Fully folded over — show back or nothing
        half3 backColor = half3(0.91h, 0.90h, 0.89h);
        return half4(backColor * 0.85h, original.a * 0.6h);
    }

    // Not peeled — add shadow near fold line
    float shadowDist = abs(peelDist - threshold);
    half shadow = half(smoothstep(0.08, 0.0, shadowDist)) * 0.2h * half(peelAmount);
    return half4(original.rgb * (1.0h - shadow), original.a);
}
