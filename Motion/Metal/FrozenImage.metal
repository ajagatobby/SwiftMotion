//
//  FrozenImage.metal
//  Motion
//
//  Physically-based frozen glass — frost grows from touch point.
//  Bilateral blur, domain-warped dendrites, Fresnel, SSS.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}
static float hash2(float2 p) {
    return fract(sin(dot(p, float2(269.5, 183.3))) * 28735.29);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash(i), hash(i + float2(1,0)), u.x),
               mix(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x), u.y);
}

static float2 noiseGrad(float2 p, float eps) {
    return float2(noise(p + float2(eps,0)) - noise(p - float2(eps,0)),
                  noise(p + float2(0,eps)) - noise(p - float2(0,eps))) / (2.0 * eps);
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

static float domainWarp(float2 uv, float t) {
    float2 q = float2(fbm(uv + t * 0.03, 5), fbm(uv + float2(5.2, 1.3) + t * 0.02, 5));
    float2 r = float2(fbm(uv + 4.0 * q + float2(1.7, 9.2), 5), fbm(uv + 4.0 * q + float2(8.3, 2.8), 5));
    return fbm(uv + 4.0 * r, 5);
}

static float2 voronoiDist(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 n = float2(float(x), float(y));
            float2 pt = float2(hash(i + n), hash2(i + n));
            float d = length(n + pt - f);
            if (d < d1) { d2 = d1; d1 = d; }
            else if (d < d2) { d2 = d; }
        }
    }
    return float2(d1, d2 - d1);
}

static float fresnelIce(float cosT) {
    float r0 = 0.018;
    return r0 + (1.0 - r0) * pow(1.0 - cosT, 5.0);
}

[[ stitchable ]] half4 frozenEffect(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float touchX,
    float touchY,
    float freezeRadius,
    float time,
    float intensity
) {
    half4 original = layer.sample(position);
    if (original.a < 0.001h) return original;

    float2 uv = position / size;
    float2 touchPos = float2(touchX, touchY);
    float dist = distance(position, touchPos);

    // Frost boundary with domain-warped edge
    float edgeWarp = domainWarp(uv * 3.0, time) * freezeRadius * 0.35;
    float boundary = freezeRadius + edgeWarp;
    float frostMask = smoothstep(boundary, boundary - freezeRadius * 0.15, dist) * intensity;
    if (frostMask < 0.001) return original;

    // Thickness map (multi-scale)
    float thickL = domainWarp(uv * 2.5, time * 0.4);
    float thickM = fbm(uv * 10.0 + time * 0.03, 5);
    float thickF = fbm(uv * 28.0, 4);
    float thickness = thickL * 0.5 + thickM * 0.35 + thickF * 0.15;
    thickness *= (0.55 + 0.45 * uv.y);
    float centerFade = smoothstep(0.95, 0.15, dist / max(freezeRadius, 1.0));
    thickness = thickness * 0.55 + centerFade * 0.45;
    thickness = clamp(thickness, 0.0, 1.0);

    // Surface distortion (Perlin + trig)
    float2 grad = noiseGrad(uv * 15.0 + time * 0.05, 0.005);
    float refrStr = frostMask * thickness * 6.0;
    float2 refractOff = grad * refrStr;
    refractOff.x += sin(uv.y * 40.0 + time) * 0.3 * frostMask;
    refractOff.y += cos(uv.x * 35.0 + time * 0.7) * 0.25 * frostMask;

    // Bilateral-weighted blur — very heavy
    float blurR = frostMask * (6.0 + thickness * 10.0);
    half3 blurSum = half3(0);
    float wSum = 0.0;
    float sigS = blurR * 0.5 + 0.001;
    float sigC = 0.15;
    half4 ctrColor = layer.sample(position + refractOff);

    for (int i = 0; i < 16; i++) {
        float angle = float(i) * 0.3927;
        float r = blurR * (0.4 + 0.6 * hash(uv * float(i + 1) * 3.7));
        float2 sPos = position + refractOff + float2(cos(angle), sin(angle)) * r;
        half4 sColor = layer.sample(sPos);
        float sw = exp(-(r * r) / (2.0 * sigS * sigS));
        half3 cDiff = sColor.rgb - ctrColor.rgb;
        float cDist = float(dot(cDiff, cDiff));
        float cw = exp(-cDist / (2.0 * sigC * sigC));
        float w = sw * cw;
        blurSum += sColor.rgb * half(w);
        wSum += w;
    }
    blurSum /= half(max(wSum, 0.001));

    float lum = float(blurSum.r) * 0.299 + float(blurSum.g) * 0.587 + float(blurSum.b) * 0.114;

    // Ice color composition — near full desaturation
    half3 frozen = mix(half3(blurSum), half3(half(lum)), half(0.92 * frostMask));

    // SSS blue tint
    half3 sss = half3(0.55h, 0.7h, 0.9h);
    frozen = mix(frozen, sss * half(lum + 0.25), half(thickness * 0.35 * frostMask));

    // Thick white frost — maximum coverage
    frozen = mix(frozen, half3(0.95h, 0.96h, 0.98h), half(pow(thickness, 0.8) * 0.9 * frostMask));

    // Warm refraction through thin ice
    float warmMask = (1.0 - thickness) * smoothstep(0.35, 0.7, lum);
    frozen = mix(frozen, half3(1.0h, 0.94h, 0.85h) * half(lum + 0.2), half(warmMask * 0.2 * frostMask));

    // Crystal dendrites
    float dend = domainWarp(uv * 4.5, time * 0.2);
    frozen += half3(half(smoothstep(0.35, 0.65, dend) * 0.07 * frostMask));

    // Voronoi crystal veins
    float2 vor = voronoiDist(uv * 16.0);
    float veins = pow(max(1.0 - vor.y * 12.0, 0.0), 0.35);
    frozen += half3(half(veins * 0.1 * frostMask));

    // Vertical drip streaks — thicker
    float drip = fbm(float2(uv.x * 7.0, uv.y * 1.2 + time * 0.05), 5);
    float dripMask = smoothstep(0.35, 0.58, drip) * smoothstep(0.03, 0.5, uv.y);
    frozen = mix(frozen, half3(0.9h, 0.92h, 0.96h), half(dripMask * 0.5 * frostMask));

    // Granular texture
    float grain = (noise(uv * 70.0 + time * 0.02) - 0.5) * 0.05;
    grain += (noise(uv * 120.0) - 0.5) * 0.03;
    frozen += half3(half(grain * frostMask));

    // Fresnel
    float viewCos = clamp(1.0 - length(uv - 0.5) * 1.2, 0.0, 1.0);
    frozen += half3(half(fresnelIce(viewCos) * 0.08 * frostMask));

    // Sparkle
    float sparkle = pow(max(1.0 - vor.x * 5.0, 0.0), 18.0);
    sparkle *= 0.5 + 0.5 * sin(time * 5.0 + vor.x * 45.0);
    frozen += half3(half(sparkle * 0.65 * frostMask));

    float fSpark = pow(max(noise(uv * 90.0 + time * 0.5) - 0.87, 0.0) * 7.7, 3.0);
    frozen += half3(half(fSpark * 0.4 * frostMask));

    // Frost front rim
    float rimDist = abs(dist - boundary);
    float rim = exp(-rimDist * rimDist / max(freezeRadius * 1.2, 1.0));
    frozen += half3(0.3h, 0.4h, 0.5h) * half(rim * 0.3 * frostMask);
    frozen += half3(half(smoothstep(4.0, 0.0, rimDist) * 0.15 * frostMask));

    // Alpha composite — very thick opaque frost
    float alpha = frostMask * (0.85 + thickness * 0.14 + dripMask * 0.01);
    alpha = clamp(alpha, 0.0, 1.0);
    half3 result = half3(half(alpha)) * frozen + half3(half(1.0 - alpha)) * half3(original.rgb);

    return half4(result, original.a);
}
