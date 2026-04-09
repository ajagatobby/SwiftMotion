//
//  BlackHole.metal
//  Motion
//
//  Gravitational lensing black hole with accretion disk,
//  photon ring, warped starfield, and Doppler shifting.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ── Noise helpers ──

static float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

static float hash2(float2 p) {
    float h = dot(p, float2(269.5, 183.3));
    return fract(sin(h) * 28735.2984);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + float2(1,0)), u.x),
               mix(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.1;
        a *= 0.5;
    }
    return v;
}

// ── Starfield ──

static half4 starfield(float2 uv, float layerSeed) {
    float2 cell = floor(uv);
    float2 local = fract(uv) - 0.5;

    float h = hash(cell + layerSeed);
    if (h > 0.97) { // ~3% of cells have stars
        float2 starPos = float2(hash(cell * 1.3 + layerSeed) - 0.5,
                                hash(cell * 2.7 + layerSeed + 77.0) - 0.5) * 0.8;
        float d = length(local - starPos);
        float brightness = hash2(cell + layerSeed * 3.0);
        float size = 0.008 + brightness * 0.015;
        float glow = smoothstep(size, size * 0.1, d);

        // Star color variation
        half3 col = half3(0.9h, 0.9h, 1.0h);
        if (brightness > 0.7) col = half3(1.0h, 0.85h, 0.7h); // warm stars
        if (brightness < 0.3) col = half3(0.7h, 0.8h, 1.0h);  // cool stars

        return half4(col * half(glow * (0.5 + brightness * 0.5)), half(glow));
    }
    return half4(0);
}

// ── Accretion disk ──

static half4 accretionDisk(float dist, float angle, float time, float innerR, float outerR) {
    if (dist < innerR || dist > outerR) return half4(0);

    // Radial fade
    float radialFade = smoothstep(innerR, innerR + (outerR - innerR) * 0.2, dist)
                     * smoothstep(outerR, outerR - (outerR - innerR) * 0.3, dist);

    // Swirling structure
    float spiral = angle + time * 0.8 + dist * 8.0;
    float structure = fbm(float2(spiral * 2.0, dist * 15.0 - time * 0.5));
    structure = structure * 0.7 + 0.3;

    // Hot inner edge → cooler outer
    float temp = 1.0 - smoothstep(innerR, outerR, dist);

    // Color: white-hot center → orange → dim red at edges
    half3 hotColor = half3(1.0h, 0.95h, 0.8h);
    half3 warmColor = half3(1.0h, 0.5h, 0.1h);
    half3 coolColor = half3(0.6h, 0.15h, 0.02h);

    half3 col = mix(coolColor, warmColor, half(temp));
    col = mix(col, hotColor, half(temp * temp));

    // Doppler shift — approaching side brighter/bluer, receding dimmer/redder
    float doppler = sin(angle + time * 0.8);
    col *= half(1.0 + doppler * 0.35);
    col.b += half(doppler * 0.1 * temp);

    float brightness = radialFade * structure * (0.6 + temp * 0.4);

    return half4(col * half(brightness), half(brightness * 0.9));
}

// ── Main shader ──

[[ stitchable ]] half4 blackHoleEffect(
    float2 position,
    half4 color,
    float2 size,
    float2 holePos,     // black hole center in pixels
    float time,
    float mass          // controls lensing strength
) {
    // Normalized coordinates (-1 to 1, aspect corrected)
    float aspect = size.x / size.y;
    float2 uv = (position / size - 0.5) * 2.0;
    uv.x *= aspect;

    float2 bhUV = (holePos / size - 0.5) * 2.0;
    bhUV.x *= aspect;

    // Vector from pixel to black hole
    float2 toBH = bhUV - uv;
    float dist = length(toBH);
    float2 dir = toBH / (dist + 0.0001);

    // ── Gravitational lensing ──
    float schwarzschild = mass * 0.06;
    float deflection = schwarzschild / (dist * dist + 0.0001);
    deflection = min(deflection, 2.0); // clamp extreme values

    float2 lensedUV = uv + dir * deflection;

    // ── Event horizon ──
    float eventRadius = schwarzschild * 0.8;
    float photonRadius = schwarzschild * 1.3;

    if (dist < eventRadius) {
        // Inside event horizon — pure black
        return half4(0, 0, 0, 1);
    }

    // ── Background: lensed starfield ──
    half4 stars = half4(0);
    // Multiple star layers at different scales for depth
    float2 starUV = lensedUV * 40.0;
    stars += starfield(starUV, 0.0);
    stars += starfield(lensedUV * 80.0, 50.0) * 0.6h;
    stars += starfield(lensedUV * 160.0, 100.0) * 0.3h;

    // Subtle nebula glow
    float nebula = fbm(lensedUV * 3.0 + time * 0.02);
    half3 nebulaColor = half3(0.05h, 0.02h, 0.08h) * half(nebula * nebula);

    half4 result = half4(nebulaColor + stars.rgb, 1.0h);

    // ── Photon ring ── bright ring at the photon sphere
    float photonGlow = exp(-pow((dist - photonRadius) * 25.0, 2.0));
    half3 photonColor = half3(1.0h, 0.8h, 0.5h);
    result.rgb += photonColor * half(photonGlow * 0.8);

    // ── Einstein ring ── bright ring from perfectly lensed background light
    float einsteinRadius = schwarzschild * 1.0;
    float einsteinGlow = exp(-pow((dist - einsteinRadius) * 35.0, 2.0));
    result.rgb += half3(0.6h, 0.7h, 1.0h) * half(einsteinGlow * 0.5);

    // ── Accretion disk ──
    float angle = atan2(toBH.y, toBH.x);
    float innerDisk = schwarzschild * 1.5;
    float outerDisk = schwarzschild * 5.0;

    half4 disk = accretionDisk(dist, angle, time, innerDisk, outerDisk);

    // Composite disk over background
    result.rgb = mix(result.rgb, disk.rgb, disk.a);

    // ── Lensing brightening near the hole ──
    float lensBrightening = smoothstep(photonRadius * 3.0, photonRadius, dist) * 0.15;
    result.rgb += half3(0.4h, 0.3h, 0.2h) * half(lensBrightening);

    // ── Vignette ──
    float2 vigUV = position / size - 0.5;
    float vig = 1.0 - dot(vigUV, vigUV) * 0.5;
    result.rgb *= half(vig);

    return result;
}
