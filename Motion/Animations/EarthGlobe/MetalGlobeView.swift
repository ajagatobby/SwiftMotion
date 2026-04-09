import SwiftUI
import MetalKit

struct MetalGlobeView: UIViewRepresentable {

    @Binding var activeTextureIndex: Int
    @Binding var zoom: Float
    var isDarkBackground: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomBinding: $zoom)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.backgroundColor = .black

        guard let renderer = EarthRenderer(mtkView: mtkView) else {
            fatalError("Metal is not supported on this device")
        }

        context.coordinator.renderer = renderer
        mtkView.delegate = renderer

        // Pan gesture for rotation
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        mtkView.addGestureRecognizer(panGesture)

        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        mtkView.addGestureRecognizer(pinchGesture)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.activeTextureIndex = activeTextureIndex
        context.coordinator.renderer?.zoom = zoom

        if isDarkBackground {
            uiView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1.0)
            uiView.backgroundColor = .black
        } else {
            uiView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            uiView.backgroundColor = .white
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var renderer: EarthRenderer?
        var zoomBinding: Binding<Float>
        private var lastPanLocation: CGPoint = .zero

        init(zoomBinding: Binding<Float>) {
            self.zoomBinding = zoomBinding
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let renderer = renderer else { return }

            let translation = gesture.translation(in: gesture.view)

            if gesture.state == .changed {
                let dx = Float(translation.x - lastPanLocation.x)
                let dy = Float(translation.y - lastPanLocation.y)

                renderer.rotationY += dx * 0.005
                renderer.rotationX += dy * 0.005

                // Clamp vertical rotation
                renderer.rotationX = min(max(renderer.rotationX, -.pi / 2 + 0.1), .pi / 2 - 0.1)
            }

            lastPanLocation = CGPoint(x: translation.x, y: translation.y)

            if gesture.state == .ended || gesture.state == .cancelled {
                lastPanLocation = .zero
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let renderer = renderer else { return }

            if gesture.state == .changed {
                renderer.zoom /= Float(gesture.scale)
                renderer.zoom = min(max(renderer.zoom, 1.5), 8.0)
                gesture.scale = 1.0
                // Sync back to SwiftUI binding
                zoomBinding.wrappedValue = renderer.zoom
            }
        }
    }
}
