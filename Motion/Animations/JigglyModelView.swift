
import SwiftUI
import SceneKit

// MARK: - Spring state for wiggle

struct SpringState {
    var value: CGFloat = 0
    var velocity: CGFloat = 0
    var target: CGFloat = 0

    mutating func step(dt: CGFloat, stiffness: CGFloat, damping: CGFloat) {
        let force = -stiffness * (value - target) - damping * velocity
        velocity += force * dt
        value += velocity * dt
    }
}

// MARK: - Jiggle Physics

@Observable
final class JigglePhysics {
    var rotX = SpringState()
    var rotY = SpringState()
    var rotZ = SpringState()
    var posY = SpringState()

    private var displayLink: CADisplayLink?

    let stiffness: CGFloat = 120
    let damping: CGFloat = 6

    var isDragging = false
    var dragX: CGFloat = 0
    var dragY: CGFloat = 0

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func poke() {
        // Random impulse
        rotX.velocity += CGFloat.random(in: -8...8)
        rotY.velocity += CGFloat.random(in: -8...8)
        rotZ.velocity += CGFloat.random(in: -4...4)
        posY.velocity += -3
    }

    @objc private func tick() {
        let dt: CGFloat = 1.0 / 60.0

        if isDragging {
            rotY.target = dragX * 0.3
            rotX.target = -dragY * 0.3
        } else {
            rotX.target = 0
            rotY.target = 0
        }

        rotZ.target = 0
        posY.target = 0

        rotX.step(dt: dt, stiffness: stiffness, damping: damping)
        rotY.step(dt: dt, stiffness: stiffness, damping: damping)
        rotZ.step(dt: dt, stiffness: stiffness * 1.5, damping: damping * 1.2)
        posY.step(dt: dt, stiffness: stiffness * 2, damping: damping * 1.5)
    }
}

// MARK: - View

struct JigglyModelView: View {
    @State private var scene: SCNScene?
    @State private var physics = JigglePhysics()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.93, blue: 0.90).ignoresSafeArea()

            if let scene {
                SceneView(
                    scene: scene,
                    options: [.autoenablesDefaultLighting, .allowsCameraControl]
                )
                .rotation3DEffect(.degrees(physics.rotX.value), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(physics.rotY.value), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(physics.rotZ.value), axis: (x: 0, y: 0, z: 1))
                .offset(y: physics.posY.value)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            physics.isDragging = true
                            physics.dragX = value.translation.width
                            physics.dragY = value.translation.height
                        }
                        .onEnded { value in
                            physics.isDragging = false
                            // Flick impulse from release velocity
                            let vx = value.predictedEndTranslation.width - value.translation.width
                            let vy = value.predictedEndTranslation.height - value.translation.height
                            physics.rotY.velocity += vx * 0.05
                            physics.rotX.velocity -= vy * 0.05
                            physics.rotZ.velocity += vx * 0.02
                        }
                )
                .onTapGesture {
                    physics.poke()
                }
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: physics.isDragging)
            } else {
                ProgressView("Loading model...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            VStack {
                Spacer()
                Text("tap to poke · drag to tilt · flick to spin")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.3))
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            loadModel()
            physics.start()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                appeared = true
            }
        }
        .onDisappear {
            physics.stop()
        }
    }

    private func loadModel() {
        // Try toy_drummer first
        let candidates = ["toy_drummer", "robot"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models") ??
                         Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    let loaded = try SCNScene(url: url)

                    // Setup camera
                    let cameraNode = SCNNode()
                    cameraNode.camera = SCNCamera()
                    cameraNode.camera?.fieldOfView = 45
                    cameraNode.position = SCNVector3(0, 0.1, 0.35)
                    loaded.rootNode.addChildNode(cameraNode)

                    // Ambient light
                    let ambient = SCNNode()
                    ambient.light = SCNLight()
                    ambient.light?.type = .ambient
                    ambient.light?.intensity = 500
                    ambient.light?.color = UIColor(white: 0.9, alpha: 1)
                    loaded.rootNode.addChildNode(ambient)

                    // Background
                    loaded.background.contents = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1)

                    scene = loaded
                    return
                } catch {
                    continue
                }
            }
        }
    }
}

#Preview {
    JigglyModelView()
}
