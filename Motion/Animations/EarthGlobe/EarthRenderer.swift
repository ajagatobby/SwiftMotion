import MetalKit
import ModelIO
import simd

// MARK: - Uniform Structures (must match Metal shader)

struct Uniforms {
    var modelMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var normalMatrix: simd_float4x4
    var sunDirection: simd_float3
    // Swift auto-pads 4 bytes here (SIMD3 alignment=16, size=12)
    var cameraPosition: simd_float3
    var _pad0: Float = 0 // Align to match Metal's float3 = 16 bytes
    var time: Float
    var cloudTime: Float
    var atmosphereRadius: Float
    var planetRadius: Float
}

// MARK: - EarthRenderer

final class EarthRenderer: NSObject, MTKViewDelegate {

    // Metal core
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    // Pipelines
    private var earthPipelineState: MTLRenderPipelineState!
    private var atmospherePipelineState: MTLRenderPipelineState!
    private var fresnelGlowPipelineState: MTLRenderPipelineState!
    private var previewPipelineState: MTLRenderPipelineState!
    private var transmittanceLUTComputePipeline: MTLComputePipelineState!
    private var multiScatterLUTComputePipeline: MTLComputePipelineState!

    // Depth
    private var depthStencilState: MTLDepthStencilState!
    private var atmosphereDepthState: MTLDepthStencilState!

    // Meshes
    private var earthMesh: MTKMesh!
    private var atmosphereMesh: MTKMesh!
    private var glowMesh: MTKMesh!

    // Textures
    private var dayTexture: MTLTexture!
    private var nightTexture: MTLTexture!
    private var normalMapTexture: MTLTexture!
    private var specularMapTexture: MTLTexture!
    private var cloudTexture: MTLTexture!
    private var transmittanceLUT: MTLTexture!
    private var multiScatterLUT: MTLTexture!

    // Camera & interaction
    var rotationX: Float = 0.2
    var rotationY: Float = 0.0
    var zoom: Float = 3.0 // Target zoom (set by UI/gestures)
    private var animatedZoom: Float = 5.0 // Current animated zoom value
    private var startTime: CFTimeInterval = 0

    // Intro animation
    private let introStartZoom: Float = 5.0
    private let introEndZoom: Float = 3.0
    private let introDuration: Float = 2.5 // seconds
    private var introComplete = false

    // Zoom animation smoothing (0 = instant, 1 = never reaches target)
    private let zoomSmoothFactor: Float = 0.08

    // Texture selection: 0=full render, 1=day, 2=night, 3=normal, 4=specular, 5=clouds
    var activeTextureIndex: Int = 0 {
        didSet {
            if oldValue != activeTextureIndex {
                previousTextureIndex = oldValue
                transitionProgress = 0.0
            }
        }
    }
    private var previousTextureIndex: Int = 0
    private var transitionProgress: Float = 1.0 // 0=start, 1=complete
    private let transitionSpeed: Float = 0.1

    // Globe parameters
    private let planetRadius: Float = 1.0
    private let atmosphereRadius: Float = 1.025
    private let glowRadius: Float = 1.035 // Slightly larger sphere for Fresnel glow

    // Vertex descriptor for MDLMesh
    private var vertexDescriptor: MTLVertexDescriptor!

    init?(mtkView: MTKView) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.startTime = CACurrentMediaTime()

        super.init()

        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1.0)
        mtkView.delegate = self
        mtkView.preferredFramesPerSecond = 60
        mtkView.contentScaleFactor = UIScreen.main.scale // Retina resolution
        mtkView.autoResizeDrawable = true

        setupVertexDescriptor()
        buildMeshes()
        buildPipelines()
        buildDepthStates()
        generateTextures()
        buildLUTs()
    }

    // MARK: - Vertex Descriptor

    private func setupVertexDescriptor() {
        let vd = MTLVertexDescriptor()

        // Position
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0

        // Normal
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = 12
        vd.attributes[1].bufferIndex = 0

        // Texture coordinate
        vd.attributes[2].format = .float2
        vd.attributes[2].offset = 24
        vd.attributes[2].bufferIndex = 0

        // Tangent
        vd.attributes[3].format = .float3
        vd.attributes[3].offset = 32
        vd.attributes[3].bufferIndex = 0

        // Bitangent
        vd.attributes[4].format = .float3
        vd.attributes[4].offset = 44
        vd.attributes[4].bufferIndex = 0

        vd.layouts[0].stride = 56 // 3+3+2+3+3 floats = 14 * 4 = 56 bytes
        vd.layouts[0].stepFunction = .perVertex

        self.vertexDescriptor = vd
    }

    // MARK: - Mesh Generation (MDLMesh)

    private func buildMeshes() {
        let allocator = MTKMeshBufferAllocator(device: device)

        // Convert MTLVertexDescriptor to MDLVertexDescriptor
        let mdlVertexDescriptor = MDLVertexDescriptor()

        let posAttr = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                          format: .float3, offset: 0, bufferIndex: 0)
        let normAttr = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                           format: .float3, offset: 12, bufferIndex: 0)
        let uvAttr = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                         format: .float2, offset: 24, bufferIndex: 0)
        let tanAttr = MDLVertexAttribute(name: MDLVertexAttributeTangent,
                                          format: .float3, offset: 32, bufferIndex: 0)
        let bitanAttr = MDLVertexAttribute(name: MDLVertexAttributeBitangent,
                                            format: .float3, offset: 44, bufferIndex: 0)

        mdlVertexDescriptor.attributes = NSMutableArray(array: [posAttr, normAttr, uvAttr, tanAttr, bitanAttr])
        mdlVertexDescriptor.layouts = NSMutableArray(array: [
            MDLVertexBufferLayout(stride: 56)
        ])

        // Earth sphere (high resolution for HD)
        let earthMDL = MDLMesh.newEllipsoid(
            withRadii: SIMD3<Float>(repeating: planetRadius),
            radialSegments: 128,
            verticalSegments: 96,
            geometryType: .triangles,
            inwardNormals: false,
            hemisphere: false,
            allocator: allocator
        )
        earthMDL.vertexDescriptor = mdlVertexDescriptor
        earthMDL.addTangentBasis(
            forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
            tangentAttributeNamed: MDLVertexAttributeTangent,
            bitangentAttributeNamed: MDLVertexAttributeBitangent
        )

        // Atmosphere sphere (slightly larger)
        let atmMDL = MDLMesh.newEllipsoid(
            withRadii: SIMD3<Float>(repeating: atmosphereRadius),
            radialSegments: 60,
            verticalSegments: 40,
            geometryType: .triangles,
            inwardNormals: false,
            hemisphere: false,
            allocator: allocator
        )
        atmMDL.vertexDescriptor = mdlVertexDescriptor
        atmMDL.addTangentBasis(
            forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
            tangentAttributeNamed: MDLVertexAttributeTangent,
            bitangentAttributeNamed: MDLVertexAttributeBitangent
        )

        // Fresnel glow sphere (slightly larger than atmosphere)
        let glowMDL = MDLMesh.newEllipsoid(
            withRadii: SIMD3<Float>(repeating: glowRadius),
            radialSegments: 60,
            verticalSegments: 40,
            geometryType: .triangles,
            inwardNormals: false,
            hemisphere: false,
            allocator: allocator
        )
        glowMDL.vertexDescriptor = mdlVertexDescriptor
        glowMDL.addTangentBasis(
            forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
            tangentAttributeNamed: MDLVertexAttributeTangent,
            bitangentAttributeNamed: MDLVertexAttributeBitangent
        )

        do {
            earthMesh = try MTKMesh(mesh: earthMDL, device: device)
            atmosphereMesh = try MTKMesh(mesh: atmMDL, device: device)
            glowMesh = try MTKMesh(mesh: glowMDL, device: device)
        } catch {
            fatalError("Failed to create meshes: \(error)")
        }
    }

    // MARK: - Pipeline States

    private func buildPipelines() {
        // Earth surface pipeline
        let earthPipelineDesc = MTLRenderPipelineDescriptor()
        earthPipelineDesc.vertexFunction = library.makeFunction(name: "earthVertexShader")
        earthPipelineDesc.fragmentFunction = library.makeFunction(name: "earthFragmentShader")
        earthPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        earthPipelineDesc.depthAttachmentPixelFormat = .depth32Float
        earthPipelineDesc.vertexDescriptor = vertexDescriptor

        // Atmosphere pipeline (alpha blending)
        let atmPipelineDesc = MTLRenderPipelineDescriptor()
        atmPipelineDesc.vertexFunction = library.makeFunction(name: "atmosphereVertexShader")
        atmPipelineDesc.fragmentFunction = library.makeFunction(name: "atmosphereFragmentShader")
        atmPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        atmPipelineDesc.colorAttachments[0].isBlendingEnabled = true
        atmPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        atmPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        atmPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        atmPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        atmPipelineDesc.depthAttachmentPixelFormat = .depth32Float
        atmPipelineDesc.vertexDescriptor = vertexDescriptor

        // Preview pipeline (single texture on globe)
        let previewPipelineDesc = MTLRenderPipelineDescriptor()
        previewPipelineDesc.vertexFunction = library.makeFunction(name: "earthVertexShader")
        previewPipelineDesc.fragmentFunction = library.makeFunction(name: "previewFragmentShader")
        previewPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        previewPipelineDesc.depthAttachmentPixelFormat = .depth32Float
        previewPipelineDesc.vertexDescriptor = vertexDescriptor

        // Fresnel glow pipeline (alpha blending, renders on glow sphere)
        let glowPipelineDesc = MTLRenderPipelineDescriptor()
        glowPipelineDesc.vertexFunction = library.makeFunction(name: "earthVertexShader")
        glowPipelineDesc.fragmentFunction = library.makeFunction(name: "fresnelGlowFragmentShader")
        glowPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        glowPipelineDesc.colorAttachments[0].isBlendingEnabled = true
        glowPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        glowPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        glowPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        glowPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        glowPipelineDesc.depthAttachmentPixelFormat = .depth32Float
        glowPipelineDesc.vertexDescriptor = vertexDescriptor

        // Compute pipelines for LUTs
        guard let transmittanceFunc = library.makeFunction(name: "computeTransmittanceLUT"),
              let multiScatterFunc = library.makeFunction(name: "computeMultipleScatteringLUT") else {
            fatalError("Failed to find compute functions")
        }

        do {
            earthPipelineState = try device.makeRenderPipelineState(descriptor: earthPipelineDesc)
            atmospherePipelineState = try device.makeRenderPipelineState(descriptor: atmPipelineDesc)
            fresnelGlowPipelineState = try device.makeRenderPipelineState(descriptor: glowPipelineDesc)
            previewPipelineState = try device.makeRenderPipelineState(descriptor: previewPipelineDesc)
            transmittanceLUTComputePipeline = try device.makeComputePipelineState(function: transmittanceFunc)
            multiScatterLUTComputePipeline = try device.makeComputePipelineState(function: multiScatterFunc)
        } catch {
            fatalError("Failed to create pipeline states: \(error)")
        }
    }

    // MARK: - Depth States

    private func buildDepthStates() {
        let earthDepthDesc = MTLDepthStencilDescriptor()
        earthDepthDesc.depthCompareFunction = .less
        earthDepthDesc.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: earthDepthDesc)

        let atmDepthDesc = MTLDepthStencilDescriptor()
        atmDepthDesc.depthCompareFunction = .less
        atmDepthDesc.isDepthWriteEnabled = false // Don't write depth for transparent atmosphere
        atmosphereDepthState = device.makeDepthStencilState(descriptor: atmDepthDesc)
    }

    // MARK: - Texture Loading

    private func generateTextures() {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .generateMipmaps: true,
            .SRGB: false
        ]

        // Load NASA textures from bundle (Solar System Scope, CC BY 4.0)
        dayTexture = loadTexture(loader: loader, name: "earth_daymap", ext: "jpg", options: options)
        nightTexture = loadTexture(loader: loader, name: "earth_nightmap", ext: "jpg", options: options)
        normalMapTexture = loadTexture(loader: loader, name: "earth_normal_map", ext: "tif", options: options)
        specularMapTexture = loadTexture(loader: loader, name: "earth_specular_map", ext: "tif", options: options)
        cloudTexture = loadTexture(loader: loader, name: "earth_clouds", ext: "jpg", options: options)

        // Fallback to procedural textures if any file is missing
        if dayTexture == nil || nightTexture == nil || normalMapTexture == nil
            || specularMapTexture == nil || cloudTexture == nil {
            let generator = TextureGenerator(device: device)
            dayTexture = dayTexture ?? generator.generateDayTexture(width: 2048, height: 1024)
            nightTexture = nightTexture ?? generator.generateNightTexture(width: 2048, height: 1024)
            normalMapTexture = normalMapTexture ?? generator.generateNormalMap(width: 2048, height: 1024)
            specularMapTexture = specularMapTexture ?? generator.generateSpecularMap(width: 2048, height: 1024)
            cloudTexture = cloudTexture ?? generator.generateCloudTexture(width: 2048, height: 1024)
        }
    }

    private func loadTexture(loader: MTKTextureLoader, name: String, ext: String,
                             options: [MTKTextureLoader.Option: Any]) -> MTLTexture? {
        // Try loading from bundle resource (Textures folder)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Textures") {
            return try? loader.newTexture(URL: url, options: options)
        }
        // Try loading from bundle root
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return try? loader.newTexture(URL: url, options: options)
        }
        return nil
    }

    // MARK: - LUT Precomputation

    private func buildLUTs() {
        // Transmittance LUT: 256 x 64
        let transDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 256, height: 64,
            mipmapped: false
        )
        transDesc.usage = [.shaderRead, .shaderWrite]
        transmittanceLUT = device.makeTexture(descriptor: transDesc)!
        transmittanceLUT.label = "Transmittance LUT"

        // Multiple scattering LUT: 32 x 32
        let msDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: 32, height: 32,
            mipmapped: false
        )
        msDesc.usage = [.shaderRead, .shaderWrite]
        multiScatterLUT = device.makeTexture(descriptor: msDesc)!
        multiScatterLUT.label = "Multi-Scatter LUT"

        // Compute the LUTs
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        // Transmittance LUT
        computeEncoder.setComputePipelineState(transmittanceLUTComputePipeline)
        computeEncoder.setTexture(transmittanceLUT, index: 0)
        let transThreadgroups = MTLSize(
            width: (256 + 15) / 16,
            height: (64 + 15) / 16,
            depth: 1
        )
        let transThreadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        computeEncoder.dispatchThreadgroups(transThreadgroups, threadsPerThreadgroup: transThreadgroupSize)

        // Multiple scattering LUT (depends on transmittance LUT)
        computeEncoder.setComputePipelineState(multiScatterLUTComputePipeline)
        computeEncoder.setTexture(multiScatterLUT, index: 0)
        computeEncoder.setTexture(transmittanceLUT, index: 1)
        let msThreadgroups = MTLSize(width: (32 + 7) / 8, height: (32 + 7) / 8, depth: 1)
        let msThreadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
        computeEncoder.dispatchThreadgroups(msThreadgroups, threadsPerThreadgroup: msThreadgroupSize)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // MARK: - Matrix Helpers

    private func makeProjectionMatrix(aspectRatio: Float) -> simd_float4x4 {
        let fov: Float = 45.0 * .pi / 180.0
        let near: Float = 0.1
        let far: Float = 100.0

        let y = 1.0 / tan(fov * 0.5)
        let x = y / aspectRatio
        let z = far / (near - far)

        return simd_float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * near, 0)
        ))
    }

    private func makeLookAtMatrix(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = normalize(center - eye)
        let s = normalize(cross(f, up))
        let u = cross(s, f)

        return simd_float4x4(columns: (
            SIMD4<Float>(s.x, u.x, -f.x, 0),
            SIMD4<Float>(s.y, u.y, -f.y, 0),
            SIMD4<Float>(s.z, u.z, -f.z, 0),
            SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        ))
    }

    private func makeRotationMatrix(angleX: Float, angleY: Float) -> simd_float4x4 {
        let cosX = cos(angleX)
        let sinX = sin(angleX)
        let cosY = cos(angleY)
        let sinY = sin(angleY)

        let rotX = simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cosX, sinX, 0),
            SIMD4<Float>(0, -sinX, cosX, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))

        let rotY = simd_float4x4(columns: (
            SIMD4<Float>(cosY, 0, -sinY, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(sinY, 0, cosY, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))

        return rotY * rotX
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let time = Float(CACurrentMediaTime() - startTime)
        let aspect = Float(view.drawableSize.width / view.drawableSize.height)

        // Intro zoom animation (ease-out cubic for first 2.5s)
        if time < introDuration {
            let t = time / introDuration
            let eased = 1.0 - pow(1.0 - t, 3.0)
            animatedZoom = introStartZoom + (introEndZoom - introStartZoom) * eased
        } else {
            if !introComplete {
                introComplete = true
                zoom = introEndZoom
                animatedZoom = introEndZoom
            }
            // Smooth interpolation: animatedZoom chases zoom target
            animatedZoom += (zoom - animatedZoom) * zoomSmoothFactor
        }

        // Camera position
        let cameraPos = SIMD3<Float>(0, 0, animatedZoom)

        // Matrices
        let modelMatrix = makeRotationMatrix(angleX: rotationX, angleY: rotationY + time * 0.05)
        let viewMatrix = makeLookAtMatrix(eye: cameraPos, center: SIMD3<Float>(0, 0, 0), up: SIMD3<Float>(0, 1, 0))
        let projMatrix = makeProjectionMatrix(aspectRatio: aspect)

        // Normal matrix (transpose of inverse of model matrix upper-left 3x3)
        let normalMatrix = modelMatrix.inverse.transpose

        // Sun direction (very slow orbit, always mostly frontal so globe stays lit)
        let sunAngle = time * 0.005
        let sunDir = normalize(SIMD3<Float>(cos(sunAngle) * 0.5, 0.3, 0.8 + sin(sunAngle) * 0.2))

        var uniforms = Uniforms(
            modelMatrix: modelMatrix,
            viewMatrix: viewMatrix,
            projectionMatrix: projMatrix,
            normalMatrix: normalMatrix,
            sunDirection: sunDir,
            cameraPosition: cameraPos,
            time: time,
            cloudTime: time,
            atmosphereRadius: atmosphereRadius,
            planetRadius: planetRadius
        )

        // -- Render Pass --
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return }

        // Advance crossfade transition
        transitionProgress = min(transitionProgress + transitionSpeed, 1.0)

        let isPreviewMode = activeTextureIndex > 0
        let wasPreviewMode = previousTextureIndex > 0
        let isTransitioning = transitionProgress < 1.0

        if isPreviewMode {
            // Preview mode: show a single texture on the globe with crossfade
            renderEncoder.setRenderPipelineState(previewPipelineState)
            renderEncoder.setDepthStencilState(depthStencilState)
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            // Smooth ease-out transition
            var mixValue = transitionProgress
            mixValue = 1.0 - pow(1.0 - mixValue, 2.5) // ease-out
            renderEncoder.setFragmentBytes(&mixValue, length: MemoryLayout<Float>.stride, index: 2)

            // Current texture
            let allTextures = [dayTexture!, nightTexture!, normalMapTexture!, specularMapTexture!, cloudTexture!]
            renderEncoder.setFragmentTexture(allTextures[activeTextureIndex - 1], index: 0)

            // Previous texture for crossfade
            if isTransitioning && wasPreviewMode {
                renderEncoder.setFragmentTexture(allTextures[previousTextureIndex - 1], index: 1)
            } else if isTransitioning && !wasPreviewMode {
                // Transitioning from full render to preview — use day texture as previous
                renderEncoder.setFragmentTexture(dayTexture, index: 1)
            } else {
                // No transition — bind same texture to both slots
                renderEncoder.setFragmentTexture(allTextures[activeTextureIndex - 1], index: 1)
            }

        } else {
            // Full render mode
            renderEncoder.setRenderPipelineState(earthPipelineState)
            renderEncoder.setDepthStencilState(depthStencilState)
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)

            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            renderEncoder.setFragmentTexture(dayTexture, index: 0)
            renderEncoder.setFragmentTexture(nightTexture, index: 1)
            renderEncoder.setFragmentTexture(normalMapTexture, index: 2)
            renderEncoder.setFragmentTexture(specularMapTexture, index: 3)
            renderEncoder.setFragmentTexture(cloudTexture, index: 4)
            renderEncoder.setFragmentTexture(transmittanceLUT, index: 5)
        }

        // Draw earth mesh
        for (i, vertexBuffer) in earthMesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: i)
        }
        for submesh in earthMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }

        // 2. Draw Atmosphere (always — visible in all modes)
        renderEncoder.setRenderPipelineState(atmospherePipelineState)
        renderEncoder.setDepthStencilState(atmosphereDepthState)
        renderEncoder.setCullMode(.front)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderEncoder.setFragmentTexture(transmittanceLUT, index: 0)
        renderEncoder.setFragmentTexture(multiScatterLUT, index: 1)

        for (i, vertexBuffer) in atmosphereMesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: i)
        }
        for submesh in atmosphereMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }

        // 3. Draw Fresnel Glow (edge glow with day/night masking)
        renderEncoder.setRenderPipelineState(fresnelGlowPipelineState)
        renderEncoder.setDepthStencilState(atmosphereDepthState)
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)

        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        for (i, vertexBuffer) in glowMesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: i)
        }
        for submesh in glowMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
