#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 normalMatrix;
    float3 sunDirection;
    float3 cameraPosition;
    float time;
    float cloudTime;
    float atmosphereRadius;
    float planetRadius;
};

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoord  [[attribute(2)]];
    float3 tangent   [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoord;
    float3 worldTangent;
    float3 worldBitangent;
};

struct AtmosphereVertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 localPosition;
};

// MARK: - Physical Constants

constant float PI = 3.14159265359;
constant float INV_4PI = 1.0 / (4.0 * PI);

// Rayleigh scattering coefficients at sea level (wavelength-dependent)
// beta_R(lambda) ~ 1/lambda^4 : blue scatters ~5.7x more than red
constant float3 C_RAYLEIGH = float3(5.802e-3, 13.558e-3, 33.1e-3);

// Ozone absorption (stratospheric)
constant float3 C_OZONE = float3(0.650e-3, 1.881e-3, 0.085e-3);

// Mie scattering and absorption
constant float C_MIE_SCAT = 3.996e-3;
constant float C_MIE_ABS  = 0.440e-3;
constant float C_MIE_EXT  = C_MIE_SCAT + C_MIE_ABS; // extinction

// Scale heights (as fraction of atmosphere thickness)
constant float H_R = 8.5 / 60.0;   // Rayleigh: 8.5 km
constant float H_M = 1.2 / 60.0;   // Mie: 1.2 km

// Mie anisotropy (Cornette-Shanks clamped)
constant float MIE_G = 0.76;

constant int LUT_TRANS_W = 256;
constant int LUT_TRANS_H = 64;
constant int LUT_MS_SIZE = 32;

// MARK: - Phase Functions

// Rayleigh: symmetric, 3/(16*pi) * (1 + cos^2 theta)
float phaseRayleigh(float costh) {
    return (3.0 / (16.0 * PI)) * (1.0 + costh * costh);
}

// Mie: Cornette-Shanks (improved Henyey-Greenstein, avoids singularity)
float phaseMie(float costh, float g) {
    float g2 = g * g;
    float k = 1.55 * g - 0.55 * g * g2; // Cornette-Shanks clamping
    float kcosth = k * costh;
    return (1.0 - k * k) / ((4.0 * PI) * (1.0 - kcosth) * (1.0 - kcosth));
}

// MARK: - Density Functions

float densityR(float h, float planetR, float atmR) {
    return exp(-max(0.0, (h - planetR) / (atmR - planetR)) / H_R);
}

float densityM(float h, float planetR, float atmR) {
    return exp(-max(0.0, (h - planetR) / (atmR - planetR)) / H_M);
}

float densityO(float h, float planetR, float atmR) {
    float normalized = (h - planetR) / (atmR - planetR);
    float ozonePeak = 25.0 / 60.0;
    return max(0.0, 1.0 - abs(normalized - ozonePeak) / (ozonePeak * 0.5)) * 0.3;
}

// MARK: - Ray-Sphere Intersection

float2 raySphereIntersect(float3 ro, float3 rd, float3 center, float radius) {
    float3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float disc = b * b - c;
    float sqrtD = sqrt(max(0.0, disc));
    float valid = step(0.0, disc);
    return float2(-b - sqrtD, -b + sqrtD) * valid + float2(-1.0) * (1.0 - valid);
}

// MARK: - Transmittance (Absorption)

// T(A→B) = exp(-optical_depth(A,B))
// optical_depth = integral of extinction coefficient along path
float3 absorb(float3 opticalDepth) {
    return exp(-(opticalDepth.x * C_RAYLEIGH
               + opticalDepth.y * C_MIE_EXT
               + opticalDepth.z * C_OZONE));
}

float3 integrateOpticalDepth(float3 start, float3 dir, float dist,
                              float planetR, float atmR, int steps) {
    float stepSize = dist / float(steps);
    float3 od = float3(0.0); // x=rayleigh, y=mie, z=ozone
    for (int i = 0; i < steps; i++) {
        float3 p = start + dir * (float(i) + 0.5) * stepSize;
        float h = length(p);
        od.x += densityR(h, planetR, atmR);
        od.y += densityM(h, planetR, atmR);
        od.z += densityO(h, planetR, atmR);
    }
    return od * stepSize;
}

// MARK: - Transmittance LUT Compute Shader

kernel void computeTransmittanceLUT(
    texture2d<float, access::write> lut [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uint(LUT_TRANS_W) || gid.y >= uint(LUT_TRANS_H)) return;

    float planetR = 1.0;
    float atmR = 1.025;

    float u = float(gid.x) / float(LUT_TRANS_W - 1);
    float v = float(gid.y) / float(LUT_TRANS_H - 1);

    float height = mix(planetR, atmR, v);
    float cosZenith = u * 2.0 - 1.0;
    float sinZenith = sqrt(max(0.0, 1.0 - cosZenith * cosZenith));

    float3 ro = float3(0.0, height, 0.0);
    float3 rd = float3(sinZenith, cosZenith, 0.0);

    float2 atmHit = raySphereIntersect(ro, rd, float3(0.0), atmR);
    float rayLen = max(0.0, atmHit.y);

    float2 planetHit = raySphereIntersect(ro, rd, float3(0.0), planetR);
    rayLen = mix(rayLen, min(rayLen, max(0.0, planetHit.x)), step(0.0, planetHit.x));

    float3 od = integrateOpticalDepth(ro, rd, rayLen, planetR, atmR, 40);
    float3 T = absorb(od);

    float valid = step(0.0, atmHit.y);
    T = mix(float3(1.0), T, valid);

    lut.write(float4(T, 1.0), gid);
}

// MARK: - Multiple Scattering LUT (F_ms = 1/(1-f_ms) approximation)

kernel void computeMultipleScatteringLUT(
    texture2d<float, access::write> lut [[texture(0)]],
    texture2d<float, access::read> transmittanceLUT [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uint(LUT_MS_SIZE) || gid.y >= uint(LUT_MS_SIZE)) return;

    float planetR = 1.0;
    float atmR = 1.025;

    float u = float(gid.x) / float(LUT_MS_SIZE - 1);
    float v = float(gid.y) / float(LUT_MS_SIZE - 1);

    float height = mix(planetR, atmR, v);
    float cosSunZ = u * 2.0 - 1.0;
    float sinSunZ = sqrt(max(0.0, 1.0 - cosSunZ * cosSunZ));
    float3 sunDir = float3(sinSunZ, cosSunZ, 0.0);

    float3 totalScatter = float3(0.0);
    float3 totalTransfer = float3(0.0);
    int N = 8;

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            float theta = PI * (float(i) + 0.5) / float(N);
            float phi = 2.0 * PI * (float(j) + 0.5) / float(N);
            float sinT = sin(theta);
            float3 dir = float3(sinT * cos(phi), cos(theta), sinT * sin(phi));

            float3 pos = float3(0, height, 0);
            float2 atmHit = raySphereIntersect(pos, dir, float3(0), atmR);
            float rayLen = max(0.0, atmHit.y);
            float2 pH = raySphereIntersect(pos, dir, float3(0), planetR);
            rayLen = mix(rayLen, min(rayLen, max(0.0, pH.x)), step(0.0, pH.x));

            float stepSz = rayLen / 8.0;
            for (int s = 0; s < 8; s++) {
                float3 sp = pos + dir * (float(s) + 0.5) * stepSz;
                float h = length(sp);
                float dR = densityR(h, planetR, atmR);
                float dM = densityM(h, planetR, atmR);
                float3 scatter = C_RAYLEIGH * dR + C_MIE_SCAT * dM;

                float cosSun = dot(normalize(sp), sunDir);
                float lutU = (cosSun + 1.0) * 0.5;
                float lutV = saturate((h - planetR) / (atmR - planetR));
                uint2 lc = uint2(uint(lutU * float(LUT_TRANS_W - 1)),
                                 uint(lutV * float(LUT_TRANS_H - 1)));
                float3 sunT = transmittanceLUT.read(lc).rgb;

                totalScatter += scatter * sunT * stepSz;
                totalTransfer += scatter * stepSz;
            }
            totalScatter *= sinT;
            totalTransfer *= sinT;
        }
    }

    float norm = (4.0 * PI) / float(N * N);
    totalScatter *= norm;
    totalTransfer *= norm;

    float3 f_ms = totalTransfer * INV_4PI;
    float3 F_ms = 1.0 / max(float3(0.001), 1.0 - f_ms);
    float3 result = totalScatter * INV_4PI * F_ms;

    lut.write(float4(result, 1.0), gid);
}

// MARK: - Earth Surface Vertex Shader

vertex VertexOut earthVertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;

    float3x3 normalMat = float3x3(uniforms.normalMatrix[0].xyz,
                                    uniforms.normalMatrix[1].xyz,
                                    uniforms.normalMatrix[2].xyz);
    out.worldNormal = normalize(normalMat * in.normal);
    out.worldTangent = normalize(normalMat * in.tangent);
    out.worldBitangent = normalize(normalMat * in.bitangent);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Earth Surface Fragment Shader

fragment float4 earthFragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> dayTexture [[texture(0)]],
    texture2d<float> nightTexture [[texture(1)]],
    texture2d<float> normalMap [[texture(2)]],
    texture2d<float> specularMap [[texture(3)]],
    texture2d<float> cloudTexture [[texture(4)]],
    texture2d<float> transmittanceLUT [[texture(5)]]
) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear,
                                  mip_filter::linear, address::repeat);

    float3 N = normalize(in.worldNormal);
    float3 T = normalize(in.worldTangent);
    float3 B = normalize(in.worldBitangent);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 L = normalize(uniforms.sunDirection);
    float2 uv = in.texCoord;

    // Normal mapping: unpack n = 2*RGB - 1, transform via TBN
    float3 localN = normalize(normalMap.sample(texSampler, uv).rgb * 2.0 - 1.0);
    float3x3 TBN = float3x3(T, B, N);
    float3 worldN = normalize(TBN * localN);

    // Diffuse lighting
    float NdotL = dot(worldN, L);
    float diffuse = max(NdotL, 0.0);

    // Day/night blend via exponential falloff
    float dayWeight = saturate(NdotL * 3.0 + 0.3);
    dayWeight = pow(dayWeight, 1.5);

    float4 dayColor = dayTexture.sample(texSampler, uv);
    float4 nightColor = nightTexture.sample(texSampler, uv);
    float3 surfaceColor = mix(nightColor.rgb, dayColor.rgb * (diffuse + 0.12), dayWeight);

    // Specular: reflect(-L, N) dot V for ocean glare
    float specMask = specularMap.sample(texSampler, uv).r;
    float3 R = reflect(-L, worldN);
    float spec = pow(max(dot(R, V), 0.0), 64.0) * specMask * diffuse;
    surfaceColor += float3(1.0, 0.95, 0.8) * spec * 1.5;

    // Clouds + shadows
    float2 cloudUV = uv + float2(uniforms.cloudTime * 0.001, 0.0);
    float4 cSample = cloudTexture.sample(texSampler, cloudUV);
    float cloudA = max(cSample.a, dot(cSample.rgb, float3(0.299, 0.587, 0.114)));
    float cDiff = max(dot(N, L), 0.0);
    float3 cColor = cSample.rgb * (cDiff * 0.9 + 0.1);

    float3 shadowOff = dot(N, L) * N - L;
    float3x3 invTBN = transpose(TBN);
    float2 sUV = uv + (invTBN * shadowOff).xy * 0.005;
    float4 sSample = cloudTexture.sample(texSampler, sUV + float2(uniforms.cloudTime * 0.001, 0.0));
    float sCloud = max(sSample.a, dot(sSample.rgb, float3(0.299, 0.587, 0.114)));
    surfaceColor *= 1.0 - sCloud * 0.35 * saturate(NdotL);
    surfaceColor = mix(surfaceColor, cColor, cloudA * 0.85);

    // Surface transmittance from LUT
    float planetR = uniforms.planetRadius;
    float atmR = uniforms.atmosphereRadius;
    float3 sNorm = normalize(in.worldPosition);
    float cosVZ = dot(sNorm, V);
    float lutU = (cosVZ + 1.0) * 0.5;
    float lutV = saturate((length(in.worldPosition) - planetR) / (atmR - planetR));
    float3 viewT = transmittanceLUT.sample(texSampler, float2(lutU, lutV)).rgb;
    surfaceColor *= viewT;

    return float4(surfaceColor, 1.0);
}

// MARK: - Atmosphere Vertex Shader

vertex AtmosphereVertexOut atmosphereVertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    AtmosphereVertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.localPosition = in.position;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    return out;
}

// MARK: - Atmosphere Fragment Shader (Physical Ray Marching)
//
// Full rendering equation with:
// - Rayleigh scattering (wavelength-dependent blue glow, 1/lambda^4)
// - Mie scattering (Cornette-Shanks, forward-scatter sun halo)
// - Ozone absorption
// - Exponential sample distribution (concentrated near surface)
// - Transmittance + multiple scattering LUTs
// - Sigmoid day/night transition for the glow

fragment float4 atmosphereFragmentShader(
    AtmosphereVertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    texture2d<float> transmittanceLUT [[texture(0)]],
    texture2d<float> multiScatterLUT [[texture(1)]]
) {
    constexpr sampler lutSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);

    float planetR = uniforms.planetRadius;
    float atmR = uniforms.atmosphereRadius;
    float3 sunDir = normalize(uniforms.sunDirection);
    float3 camPos = uniforms.cameraPosition;
    float3 rayDir = normalize(in.worldPosition - camPos);

    // Ray-atmosphere intersection
    float2 atmHit = raySphereIntersect(camPos, rayDir, float3(0.0), atmR);
    if (atmHit.y < 0.0) discard_fragment();

    float tStart = max(atmHit.x, 0.0);
    float tEnd = atmHit.y;

    // Planet occlusion
    float2 planetHit = raySphereIntersect(camPos, rayDir, float3(0.0), planetR);
    float hitsPlanet = step(0.0, planetHit.x);
    tEnd = mix(tEnd, min(tEnd, planetHit.x), hitsPlanet);

    float rayLength = tEnd - tStart;
    if (rayLength <= 0.0) discard_fragment();

    // Phase functions (constant along ray)
    float cosTheta = dot(rayDir, sunDir);
    float phR = phaseRayleigh(cosTheta);
    float phM = phaseMie(cosTheta, MIE_G);

    // Ray marching with exponential sample distribution
    // More samples near the planet surface where density is highest
    int numSteps = 32;
    float exposure = 20.0;

    float3 rayleighSum = float3(0.0);
    float3 mieSum = float3(0.0);
    float3 opticalDepth = float3(0.0); // x=R, y=M, z=O

    float prevT = 0.0;
    for (int i = 0; i < numSteps; i++) {
        // Exponential distribution: concentrate samples near surface
        float t_frac = float(i + 1) / float(numSteps);
        float t_exp = t_frac * t_frac; // Quadratic = more samples near start
        float t_cur = t_exp * rayLength;
        float stepSize = t_cur - prevT;
        prevT = t_cur;

        float3 samplePos = camPos + rayDir * (tStart + t_cur - stepSize * 0.5);
        float sampleHeight = length(samplePos);

        // Density at this height
        float dR = densityR(sampleHeight, planetR, atmR);
        float dM = densityM(sampleHeight, planetR, atmR);
        float dO = densityO(sampleHeight, planetR, atmR);

        // Accumulate optical depth along view ray
        opticalDepth += float3(dR, dM, dO) * stepSize;

        // Transmittance from camera to this sample: T = exp(-tau)
        float3 viewTrans = absorb(opticalDepth);

        // Transmittance from sample to sun (LUT)
        float3 sNorm = normalize(samplePos);
        float cosSunZ = dot(sNorm, sunDir);
        float hFrac = saturate((sampleHeight - planetR) / (atmR - planetR));
        float2 lutUV = float2((cosSunZ + 1.0) * 0.5, hFrac);
        float3 sunTrans = transmittanceLUT.sample(lutSampler, lutUV).rgb;

        // Multiple scattering (precomputed with F_ms infinite bounce factor)
        float3 ms = multiScatterLUT.sample(lutSampler, lutUV).rgb;

        // Accumulate in-scattered light
        float3 scatR = C_RAYLEIGH * dR;
        float scatM = C_MIE_SCAT * dM;

        rayleighSum += viewTrans * scatR * (sunTrans * phR + ms) * stepSize;
        mieSum += viewTrans * float3(scatM) * (sunTrans * phM + ms * 0.5) * stepSize;
    }

    float3 atmosphere = (rayleighSum + mieSum) * exposure;

    // --- Soft limb enhancement ---
    // The ray marching already creates a natural blue rim from longer optical paths.
    // Add a gentle Schlick Fresnel for subtle brightening (not a hard line).
    float3 entryPoint = camPos + rayDir * tStart;
    float3 entryNorm = normalize(entryPoint);
    float NdotV = abs(dot(entryNorm, -rayDir));

    float R0 = 0.01;
    float schlick = R0 + (1.0 - R0) * pow(1.0 - NdotV, 5.0);

    float sunAngle = dot(entryNorm, sunDir);
    float dayMask = 1.0 / (1.0 + exp(-5.0 * (sunAngle + 0.15)));

    // Gentle limb color — subtle, not a hard ring
    float rimMod = mix(0.3, 1.0, dayMask);
    atmosphere += float3(0.08, 0.22, 0.6) * schlick * rimMod * 0.5;

    // --- Tone Mapping (ACES) ---
    float3 x = atmosphere;
    atmosphere = saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14));

    // Alpha: from scattering luminance, gentle
    float lum = dot(atmosphere, float3(0.299, 0.587, 0.114));
    float alpha = saturate(lum * 2.5 + schlick * 0.3);

    // Reduce over planet surface
    alpha = mix(alpha, alpha * 0.4, hitsPlanet);

    return float4(atmosphere, alpha);
}

// MARK: - Fresnel Glow Fragment Shader
//
// Algorithm:
// 1. Compute sunlight mask (mixAmount) from dot(sunDir, normal)
// 2. Create base atmosphere color, apply mask
// 3. Compute Fresnel from dot(cameraToSurface, normal) — edges become opaque
// 4. Multiply Fresnel by mixAmount so glow fades on night side

fragment float4 fresnelGlowFragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    // Surface normal in world space (used as camera-coordinate proxy)
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(uniforms.sunDirection);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);

    // --- Step 1: Sunlight Masking (Day/Night) ---
    // Cosine of angle between sun direction and surface normal
    float cosAngleSunToNormal = dot(N, L);
    // mixAmount: 1 on full day side, 0 on full night side, smooth transition
    float mixAmount = saturate(cosAngleSunToNormal * 2.0 + 0.5);
    mixAmount = pow(mixAmount, 1.5);

    // --- Step 2: Base Atmosphere Color ---
    // Blue atmosphere color, masked by day/night
    float3 u_color = float3(0.3, 0.6, 1.0);
    float3 baseAtmosphere = u_color * mixAmount;

    // --- Step 3: Fresnel Effect (Edge Glow) ---
    // Angle between camera-to-surface vector and surface normal
    // At center: dot(V, N) ≈ 1 → fresnel ≈ 0 (transparent)
    // At edges: dot(V, N) ≈ 0 → fresnel ≈ 1 (opaque/glowing)
    float fresnelTerm = 1.0 - max(dot(V, N), 0.0);
    fresnelTerm = pow(fresnelTerm, 2.0);

    // --- Step 4: Final Masking ---
    // Multiply Fresnel by mixAmount so edge glow fades on night side
    float3 glowColor = u_color * fresnelTerm * mixAmount;

    // Combine base atmosphere and Fresnel glow
    float3 finalColor = baseAtmosphere * fresnelTerm * 0.5 + glowColor * 0.8;

    // Alpha: driven by Fresnel (edges opaque, center transparent)
    // Also masked by day/night
    float alpha = fresnelTerm * mixAmount * 0.9;

    return float4(finalColor, alpha);
}

// MARK: - Preview Fragment Shader (with crossfade)

fragment float4 previewFragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    constant float &transitionMix [[buffer(2)]],
    texture2d<float> currentTexture [[texture(0)]],
    texture2d<float> previousTexture [[texture(1)]]
) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear,
                                  mip_filter::linear, address::repeat);

    float3 N = normalize(in.worldNormal);
    float3 L = normalize(uniforms.sunDirection);
    float2 uv = in.texCoord;

    float4 curColor = currentTexture.sample(texSampler, uv);
    float4 prevColor = previousTexture.sample(texSampler, uv);

    // Crossfade between previous and current texture
    float4 texColor = mix(prevColor, curColor, transitionMix);

    float lighting = max(dot(N, L), 0.0) * 0.7 + 0.3;

    return float4(texColor.rgb * lighting, 1.0);
}
