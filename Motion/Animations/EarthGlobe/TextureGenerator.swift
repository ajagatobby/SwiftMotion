import MetalKit
import CoreGraphics

/// Generates procedural placeholder textures for the Earth globe.
/// Replace these with real NASA/satellite textures for production quality.
/// Recommended textures:
///   - Day:     "earth_daymap.jpg" (NASA Blue Marble)
///   - Night:   "earth_nightmap.jpg" (NASA Black Marble / city lights)
///   - Normal:  "earth_normal.jpg" (topographic normal map)
///   - Specular:"earth_specular.jpg" (ocean mask)
///   - Cloud:   "earth_clouds.png" (cloud cover with alpha)
final class TextureGenerator {

    private let device: MTLDevice

    init(device: MTLDevice) {
        self.device = device
    }

    // MARK: - Noise Helpers

    /// Simple value noise using hashing
    private static func hash(_ n: Float) -> Float {
        let x = sin(n) * 43758.5453123
        return x - floor(x)
    }

    private static func hash2D(_ x: Float, _ y: Float) -> Float {
        return hash(x * 127.1 + y * 311.7)
    }

    private static func smoothNoise(_ x: Float, _ y: Float) -> Float {
        let ix = floor(x)
        let iy = floor(y)
        let fx = x - ix
        let fy = y - iy

        // Smoothstep
        let ux = fx * fx * (3.0 - 2.0 * fx)
        let uy = fy * fy * (3.0 - 2.0 * fy)

        let a = hash2D(ix, iy)
        let b = hash2D(ix + 1, iy)
        let c = hash2D(ix, iy + 1)
        let d = hash2D(ix + 1, iy + 1)

        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    }

    private static func fbm(_ x: Float, _ y: Float, octaves: Int = 6) -> Float {
        var value: Float = 0.0
        var amplitude: Float = 0.5
        var px = x
        var py = y

        for _ in 0..<octaves {
            value += amplitude * smoothNoise(px, py)
            px *= 2.0
            py *= 2.0
            amplitude *= 0.5
        }
        return value
    }

    /// Worley (cellular) noise for clouds
    private static func worley(_ x: Float, _ y: Float) -> Float {
        let ix = floor(x)
        let iy = floor(y)
        var minDist: Float = 1.0

        for dx in -1...1 {
            for dy in -1...1 {
                let cx = ix + Float(dx)
                let cy = iy + Float(dy)
                let px = cx + hash2D(cx, cy)
                let py = cy + hash2D(cy + 31.0, cx + 17.0)
                let dist = (x - px) * (x - px) + (y - py) * (y - py)
                minDist = min(minDist, dist)
            }
        }
        return sqrt(minDist)
    }

    // MARK: - Texture Creation Helper

    private func createTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba8Unorm) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width, height: height,
            mipmapped: true
        )
        desc.usage = [.shaderRead]
        return device.makeTexture(descriptor: desc)!
    }

    private func uploadPixels(_ pixels: [UInt8], to texture: MTLTexture, width: Int, height: Int) {
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4
        )

        // Generate mipmaps
        if let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
           let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: texture)
            blitEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }

    // MARK: - Day Texture (Earth with continents)

    func generateDayTexture(width: Int, height: Int) -> MTLTexture {
        let texture = createTexture(width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                // Convert to spherical coordinates for seamless wrapping
                let lon = u * 2.0 * .pi
                let lat = (v - 0.5) * .pi

                let sx = cos(lat) * cos(lon)
                let sy = sin(lat)
                let sz = cos(lat) * sin(lon)

                // Generate continent shapes using FBM noise in 3D (projected)
                let scale: Float = 3.0
                let n1 = Self.fbm(sx * scale + 1.5, sz * scale + 0.7, octaves: 6)
                let n2 = Self.fbm(sx * scale * 0.5 + 3.2, sy * scale * 0.5 + 1.1, octaves: 4)
                let landMask = (n1 * 0.7 + n2 * 0.3)

                // Create latitude-based bias (more ice at poles, more land at mid-latitudes)
                let absLat = abs(lat) / (.pi * 0.5)
                let polarIce = max(0, (absLat - 0.85) * 8.0)

                let isLand = landMask > 0.48

                var r: Float, g: Float, b: Float

                if polarIce > 0.5 {
                    // Ice/snow
                    r = 0.92; g = 0.94; b = 0.96
                } else if isLand {
                    // Land: green/brown with elevation variation
                    let elevation = (landMask - 0.48) * 5.0
                    let detail = Self.fbm(sx * 12.0, sz * 12.0, octaves: 3) * 0.3

                    if elevation > 0.8 {
                        // Mountains - grey/brown
                        r = 0.55 + detail; g = 0.50 + detail; b = 0.42 + detail
                    } else if absLat < 0.35 {
                        // Tropical - deep green
                        r = 0.12 + detail * 0.5; g = 0.40 + detail; b = 0.10 + detail * 0.3
                    } else if absLat < 0.55 {
                        // Temperate - lighter green
                        r = 0.25 + detail * 0.5; g = 0.45 + detail; b = 0.15 + detail * 0.3
                    } else {
                        // Taiga/Tundra - dark muted green/brown
                        r = 0.35 + detail; g = 0.38 + detail; b = 0.25 + detail
                    }
                } else {
                    // Ocean: deep blue with some variation
                    let oceanDetail = Self.fbm(sx * 8.0, sz * 8.0, octaves: 2) * 0.1
                    let depth = (0.48 - landMask) * 3.0

                    r = 0.02 + oceanDetail
                    g = 0.10 + oceanDetail + (1.0 - depth) * 0.08
                    b = 0.35 + oceanDetail + (1.0 - depth) * 0.15
                }

                let idx = (y * width + x) * 4
                pixels[idx + 0] = clampedUInt8( Int(min(max(r, 0), 1) * 255))
                pixels[idx + 1] = clampedUInt8( Int(min(max(g, 0), 1) * 255))
                pixels[idx + 2] = clampedUInt8( Int(min(max(b, 0), 1) * 255))
                pixels[idx + 3] = 255
            }
        }

        uploadPixels(pixels, to: texture, width: width, height: height)
        return texture
    }

    // MARK: - Night Texture (City Lights)

    func generateNightTexture(width: Int, height: Int) -> MTLTexture {
        let texture = createTexture(width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                let lon = u * 2.0 * .pi
                let lat = (v - 0.5) * .pi

                let sx = cos(lat) * cos(lon)
                let sy = sin(lat)
                let sz = cos(lat) * sin(lon)

                let scale: Float = 3.0
                let n1 = Self.fbm(sx * scale + 1.5, sz * scale + 0.7, octaves: 6)
                let n2 = Self.fbm(sx * scale * 0.5 + 3.2, sy * scale * 0.5 + 1.1, octaves: 4)
                let landMask = (n1 * 0.7 + n2 * 0.3)
                let isLand = landMask > 0.48

                var r: Float = 0.01, g: Float = 0.01, b: Float = 0.02

                if isLand {
                    // Simulate city lights with high-frequency noise
                    let cityNoise = Self.fbm(sx * 40.0, sz * 40.0, octaves: 4)
                    let coastProximity = max(0, 1.0 - (landMask - 0.48) * 10.0) // More lights near coasts
                    let absLat = abs(lat) / (.pi * 0.5)

                    // More populated in temperate zones
                    let populationWeight = max(0, 1.0 - abs(absLat - 0.35) * 3.0) * 0.7 + 0.3

                    let lightIntensity = max(0, cityNoise - 0.45) * 4.0 * populationWeight * (0.5 + coastProximity * 0.5)

                    // Warm yellow/orange city lights
                    r = min(lightIntensity * 1.0, 1.0)
                    g = min(lightIntensity * 0.75, 0.9)
                    b = min(lightIntensity * 0.3, 0.5)
                }

                let idx = (y * width + x) * 4
                pixels[idx + 0] = clampedUInt8( Int(min(max(r, 0), 1) * 255))
                pixels[idx + 1] = clampedUInt8( Int(min(max(g, 0), 1) * 255))
                pixels[idx + 2] = clampedUInt8( Int(min(max(b, 0), 1) * 255))
                pixels[idx + 3] = 255
            }
        }

        uploadPixels(pixels, to: texture, width: width, height: height)
        return texture
    }

    // MARK: - Normal Map

    func generateNormalMap(width: Int, height: Int) -> MTLTexture {
        let texture = createTexture(width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        // First generate a height map, then derive normals
        var heightMap = [Float](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                let lon = u * 2.0 * .pi
                let lat = (v - 0.5) * .pi

                let sx = cos(lat) * cos(lon)
                let sz = cos(lat) * sin(lon)

                // Use FBM for terrain height
                let n = Self.fbm(sx * 6.0, sz * 6.0, octaves: 5)
                let landMask = Self.fbm(sx * 3.0 + 1.5, sz * 3.0 + 0.7, octaves: 6)

                // Only create height on land
                let h = landMask > 0.48 ? n * (landMask - 0.48) * 5.0 : 0.0
                heightMap[y * width + x] = h
            }
        }

        // Compute normals from height map using Sobel filter
        let strength: Float = 2.0
        for y in 0..<height {
            for x in 0..<width {
                let xp = (x + 1) % width
                let xm = (x - 1 + width) % width
                let yp = min(y + 1, height - 1)
                let ym = max(y - 1, 0)

                let dX = (heightMap[y * width + xp] - heightMap[y * width + xm]) * strength
                let dY = (heightMap[yp * width + x] - heightMap[ym * width + x]) * strength

                // Normal in tangent space
                var nx = -dX
                var ny = -dY
                var nz: Float = 1.0

                // Normalize
                let len = sqrt(nx * nx + ny * ny + nz * nz)
                nx /= len; ny /= len; nz /= len

                // Pack to [0,1]: n = (n + 1) / 2
                let idx = (y * width + x) * 4
                pixels[idx + 0] = clampedUInt8( Int((nx * 0.5 + 0.5) * 255))
                pixels[idx + 1] = clampedUInt8( Int((ny * 0.5 + 0.5) * 255))
                pixels[idx + 2] = clampedUInt8( Int((nz * 0.5 + 0.5) * 255))
                pixels[idx + 3] = 255
            }
        }

        uploadPixels(pixels, to: texture, width: width, height: height)
        return texture
    }

    // MARK: - Specular Map (Ocean Mask)

    func generateSpecularMap(width: Int, height: Int) -> MTLTexture {
        let texture = createTexture(width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                let lon = u * 2.0 * .pi
                let lat = (v - 0.5) * .pi

                let sx = cos(lat) * cos(lon)
                let sy = sin(lat)
                let sz = cos(lat) * sin(lon)

                let n1 = Self.fbm(sx * 3.0 + 1.5, sz * 3.0 + 0.7, octaves: 6)
                let n2 = Self.fbm(sx * 1.5 + 3.2, sy * 1.5 + 1.1, octaves: 4)
                let landMask = (n1 * 0.7 + n2 * 0.3)

                // Specular = ocean areas (inverse of land mask)
                let spec: Float = landMask > 0.48 ? 0.0 : 1.0

                let idx = (y * width + x) * 4
                let val = clampedUInt8( Int(spec * 255))
                pixels[idx + 0] = val
                pixels[idx + 1] = val
                pixels[idx + 2] = val
                pixels[idx + 3] = 255
            }
        }

        uploadPixels(pixels, to: texture, width: width, height: height)
        return texture
    }

    // MARK: - Cloud Texture (Inverted Worley Noise)

    func generateCloudTexture(width: Int, height: Int) -> MTLTexture {
        let texture = createTexture(width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                let lon = u * 2.0 * .pi
                let lat = (v - 0.5) * .pi

                let sx = cos(lat) * cos(lon)
                let sz = cos(lat) * sin(lon)

                // Inverted Worley noise for volumetric cloud shapes
                let scale: Float = 8.0
                let w1 = 1.0 - Self.worley(sx * scale + 2.3, sz * scale + 1.7)
                let w2 = 1.0 - Self.worley(sx * scale * 2.0 + 5.1, sz * scale * 2.0 + 3.2)
                let fbmVal = Self.fbm(sx * scale * 0.5, sz * scale * 0.5, octaves: 4)

                // Combine for cloud pattern
                var cloud = (w1 * 0.5 + w2 * 0.3 + fbmVal * 0.2)

                // Apply threshold for cloud coverage (~40%)
                cloud = max(0, (cloud - 0.35) * 2.5)
                cloud = min(cloud, 1.0)

                // Reduce clouds at poles slightly
                let absLat = abs(lat) / (.pi * 0.5)
                if absLat > 0.8 {
                    cloud *= max(0, 1.0 - (absLat - 0.8) * 3.0)
                }

                let brightness = clampedUInt8( Int(min(cloud * 1.1, 1.0) * 255))
                let alpha = clampedUInt8( Int(cloud * 255))

                let idx = (y * width + x) * 4
                pixels[idx + 0] = brightness
                pixels[idx + 1] = brightness
                pixels[idx + 2] = brightness
                pixels[idx + 3] = alpha
            }
        }

        uploadPixels(pixels, to: texture, width: width, height: height)
        return texture
    }
}

// MARK: - Clamped UInt8

private func clampedUInt8(_ value: Int) -> UInt8 {
    return UInt8(Swift.min(Swift.max(value, 0), 255))
}
