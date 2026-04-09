
import SwiftUI
import CoreMotion

struct Category: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

// MARK: - 3D Capsules

struct Capsule3D: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    Capsule()
                        .fill(color)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.2)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .init(x: 0.3, y: 0.0),
                                endPoint: .init(x: 0.5, y: 0.5)
                            )
                        )
                        .scaleEffect(x: 0.92, y: 0.7)
                        .offset(y: -2)

                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .black.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Physics Body

struct CapsuleBody {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var halfLen: CGFloat      // half of (width - height) — the flat part
    var capR: CGFloat         // capsule end radius = height/2
    var width: CGFloat
    var height: CGFloat
    var launched: Bool = false
    var sleepFrames: Int = 0
    var isSleeping: Bool = false
    var onGround: Bool = false

    var mass: CGFloat { max(width * height * 0.01, 0.5) }
}

// MARK: - Physics Engine

@Observable
final class CapsulePhysics {
    var bodies: [Int: CapsuleBody] = [:]

    private var displayLink: CADisplayLink?
    private var screenW: CGFloat = 393
    private var floorY: CGFloat = 852

    private let baseGravity: CGFloat = 1800
    private let airDrag: CGFloat = 0.999
    private let groundFriction: CGFloat = 0.90
    private let substeps = 8
    private let collisionPasses = 1

    // Accelerometer
    private let motionManager = CMMotionManager()
    var gravityX: CGFloat = 0     // horizontal tilt force
    var gravityY: CGFloat = 1     // vertical tilt force (1 = straight down)

    func setSize(_ w: CGFloat, _ floor: CGFloat, _ spawn: CGFloat) {
        screenW = w; floorY = floor
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link

        // Start accelerometer
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                // Device x maps to screen x, device y maps to screen y (inverted)
                // In portrait: gravity.x = tilt left/right, gravity.y = tilt forward/back
                self.gravityX = CGFloat(data.acceleration.x)
                self.gravityY = CGFloat(-data.acceleration.y)  // invert: tilting phone back = gravity down
            }
        }
    }

    func stop() {
        displayLink?.invalidate(); displayLink = nil
        motionManager.stopAccelerometerUpdates()
    }

    func launch(id: Int, width: CGFloat, height: CGFloat, delay: Double) {
        let capR = height / 2
        let halfL = max(0, (width - height) / 2)

        bodies[id] = CapsuleBody(
            x: CGFloat.random(in: (width / 2 + 10)...(screenW - width / 2 - 10)),
            y: CGFloat.random(in: (-height * 3)...(-height)),
            vx: CGFloat.random(in: -100...100),
            vy: 0,
            halfLen: halfL,
            capR: capR,
            width: width,
            height: height
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.bodies[id]?.launched = true
        }
    }

    @objc private func tick() {
        let dt: CGFloat = 1.0 / 60.0 / CGFloat(substeps)
        for _ in 0..<substeps {
            integrate(dt: dt)
            for _ in 0..<collisionPasses {
                solveWalls()
                solveBodies()
            }
            killMicroVelocities()
            detectSleep()
        }
    }

    // Wake all sleeping bodies (called when device tilts significantly)
    func wakeAll() {
        for id in bodies.keys {
            guard var b = bodies[id] else { continue }
            if b.isSleeping {
                b.isSleeping = false
                b.sleepFrames = 0
            }
            bodies[id] = b
        }
        // Restart display link if it was stopped
        if displayLink == nil {
            start()
        }
    }

    // MARK: Integration

    private func integrate(dt: CGFloat) {
        // Tilt-based gravity: baseGravity applied in direction of device tilt
        let gx = gravityX * baseGravity
        let gy = gravityY * baseGravity

        for id in bodies.keys {
            guard var b = bodies[id], b.launched, !b.isSleeping else { continue }

            if !b.onGround {
                b.vx += gx * dt
                b.vy += gy * dt
            } else {
                // Even on ground, apply horizontal tilt so capsules slide on tilt
                b.vx += gx * dt
            }

            b.vx *= airDrag
            b.vy *= airDrag

            b.x += b.vx * dt
            b.y += b.vy * dt

            b.onGround = false

            bodies[id] = b
        }
    }

    // MARK: Wall collisions

    private func solveWalls() {
        for id in bodies.keys {
            guard var b = bodies[id], b.launched else { continue }
            let r = b.capR
            let halfW = b.halfLen + r  // total half-width of capsule

            // Floor
            if b.y + r > floorY {
                b.y = floorY - r
                if b.vy > 0 {
                    b.vy = -b.vy * 0.55
                    if abs(b.vy) < 8 { b.vy = 0; b.onGround = true }
                }
                b.vx *= groundFriction
            }

            // Left wall
            if b.x - halfW < 0 {
                b.x = halfW
                if b.vx < 0 { b.vx = -b.vx * 0.5 }
            }

            // Right wall
            if b.x + halfW > screenW {
                b.x = screenW - halfW
                if b.vx > 0 { b.vx = -b.vx * 0.5 }
            }

            bodies[id] = b
        }
    }

    // MARK: Body–body collision (horizontal capsule vs horizontal capsule)
    // Uses specialized horizontal-segment distance — numerically stable unlike
    // the general segment-segment algorithm which breaks for parallel segments.

    private func solveBodies() {
        let ids = Array(bodies.keys).sorted()

        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                guard var a = bodies[ids[i]], var b = bodies[ids[j]] else { continue }
                guard a.launched && b.launched else { continue }

                // === BROAD PHASE ===
                let aHalfW = a.halfLen + a.capR
                let bHalfW = b.halfLen + b.capR
                if abs(b.x - a.x) > aHalfW + bHalfW { continue }
                if abs(b.y - a.y) > a.capR + b.capR { continue }

                // === NARROW PHASE: horizontal capsule distance ===
                // Each capsule is a horizontal segment at its y-center.
                // A: from (a.x - a.halfLen) to (a.x + a.halfLen) at y = a.y
                // B: from (b.x - b.halfLen) to (b.x + b.halfLen) at y = b.y

                let aLeft = a.x - a.halfLen, aRight = a.x + a.halfLen
                let bLeft = b.x - b.halfLen, bRight = b.x + b.halfLen

                // X-axis separation between the two horizontal segments
                let sepX: CGFloat
                if aRight < bLeft {
                    sepX = bLeft - aRight       // A fully left of B
                } else if bRight < aLeft {
                    sepX = aLeft - bRight       // B fully left of A
                } else {
                    sepX = 0                    // X ranges overlap
                }

                let dy = b.y - a.y
                let dist = sqrt(sepX * sepX + dy * dy)
                let minDist = a.capR + b.capR

                guard dist < minDist && dist > 0.0001 else { continue }

                // Wake sleeping bodies
                if a.isSleeping { a.isSleeping = false; a.sleepFrames = 0 }
                if b.isSleeping { b.isSleeping = false; b.sleepFrames = 0 }

                // Collision normal (A → B)
                let nx: CGFloat
                let ny: CGFloat
                if dist > 0.0001 {
                    let rawNx: CGFloat
                    if sepX > 0 {
                        rawNx = (b.x > a.x) ? sepX : -sepX
                    } else {
                        rawNx = 0
                    }
                    nx = rawNx / dist
                    ny = dy / dist
                } else {
                    nx = 0; ny = dy >= 0 ? 1 : -1
                }

                // === POSITION CORRECTION (100%, mass-weighted) ===
                let overlap = minDist - dist
                let massA = a.mass, massB = b.mass
                let totalMass = massA + massB

                a.x -= nx * overlap * (massB / totalMass)
                a.y -= ny * overlap * (massB / totalMass)
                b.x += nx * overlap * (massA / totalMass)
                b.y += ny * overlap * (massA / totalMass)

                // === VELOCITY RESPONSE (bouncy) ===
                let dvx = a.vx - b.vx
                let dvy = a.vy - b.vy
                let dvDotN = dvx * nx + dvy * ny

                if dvDotN > 0 {
                    let restitution: CGFloat = 0.75
                    let impulse = -(1 + restitution) * dvDotN / (1.0 / massA + 1.0 / massB)

                    a.vx += (impulse / massA) * nx
                    a.vy += (impulse / massA) * ny
                    b.vx -= (impulse / massB) * nx
                    b.vy -= (impulse / massB) * ny

                    // Tangential friction
                    let tx = dvx - dvDotN * nx
                    let ty = dvy - dvDotN * ny
                    let tLen = sqrt(tx * tx + ty * ty)
                    if tLen > 0.1 {
                        let maxFriction = abs(dvDotN) * 0.4
                        let frictionImpulse = min(tLen, maxFriction) / (1.0 / massA + 1.0 / massB)
                        a.vx -= (tx / tLen) * frictionImpulse / massA
                        a.vy -= (ty / tLen) * frictionImpulse / massA
                        b.vx += (tx / tLen) * frictionImpulse / massB
                        b.vy += (ty / tLen) * frictionImpulse / massB
                    }
                }

                // Mark resting contact: if normal is mostly vertical,
                // the upper capsule is "on ground"
                if ny > 0.7 {
                    a.onGround = true   // A is above B
                } else if ny < -0.7 {
                    b.onGround = true   // B is above A
                }

                bodies[ids[i]] = a
                bodies[ids[j]] = b
            }
        }
    }

    // MARK: Kill micro velocities

    private func killMicroVelocities() {
        for id in bodies.keys {
            guard var b = bodies[id], b.launched, !b.isSleeping else { continue }
            if abs(b.vx) < 0.5 { b.vx = 0 }
            if abs(b.vy) < 0.5 { b.vy = 0 }
            bodies[id] = b
        }
    }

    // MARK: Sleep

    private func detectSleep() {
        // If device is tilted, wake everything
        let tiltMagnitude = abs(gravityX)
        if tiltMagnitude > 0.15 {
            wakeAll()
            return
        }

        for id in bodies.keys {
            guard var b = bodies[id], b.launched else { continue }
            if b.isSleeping { continue }

            let speed = hypot(b.vx, b.vy)
            if speed < 5 {
                b.sleepFrames += 1
                if b.sleepFrames > 10 {
                    b.isSleeping = true
                    b.vx = 0; b.vy = 0
                }
            } else {
                b.sleepFrames = 0
            }
            bodies[id] = b
        }
    }
}

// MARK: - View

struct Book: View {
    @State private var physics = CapsulePhysics()
    @State private var launched = false
    @State private var measuredSizes: [Int: CGSize] = [:]

    private let categories: [Category] = [
        Category(id: 1, name: "Fiction", color: .blue),
        Category(id: 2, name: "Non Fiction", color: .mint),
        Category(id: 3, name: "Horror", color: .green),
        Category(id: 4, name: "Comedy", color: .cyan),
        Category(id: 5, name: "Science Fiction", color: .yellow),
        Category(id: 6, name: "Romance", color: .pink),
        Category(id: 7, name: "Thriller", color: .red),
        Category(id: 8, name: "Mystery", color: .purple),
        Category(id: 9, name: "Fantasy", color: .indigo),
        Category(id: 10, name: "Biography", color: .orange),
        Category(id: 11, name: "Self Help", color: .teal),
        Category(id: 12, name: "History", color: .brown),
        Category(id: 13, name: "Poetry", color: Color(red: 0.9, green: 0.5, blue: 0.6)),
        Category(id: 14, name: "Adventure", color: Color(red: 0.9, green: 0.6, blue: 0.2)),
        Category(id: 15, name: "Philosophy", color: .gray),
        Category(id: 16, name: "True Crime", color: Color(red: 0.7, green: 0.15, blue: 0.15)),
        Category(id: 17, name: "Dystopian", color: Color(red: 0.4, green: 0.3, blue: 0.7)),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                // Hidden measuring layer
                ForEach(categories) { cat in
                    if measuredSizes[cat.id] == nil {
                        Text(cat.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .fixedSize()
                            .background(
                                GeometryReader { textGeo in
                                    Color.clear.onAppear {
                                        measuredSizes[cat.id] = textGeo.size
                                        tryLaunch()
                                    }
                                }
                            )
                            .hidden()
                    }
                }

                // Visible capsules
                ForEach(categories) { cat in
                    if let b = physics.bodies[cat.id], b.launched {
                        Capsule3D(text: cat.name, color: cat.color)
                            .position(x: b.x, y: b.y)
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                let w = geo.size.width
                let floor = geo.size.height + geo.safeAreaInsets.bottom
                physics.setSize(w, floor, floor + 60)
            }
            .onDisappear { physics.stop() }
        }
        .ignoresSafeArea()
    }

    private func tryLaunch() {
        guard !launched, measuredSizes.count == categories.count else { return }
        launched = true
        physics.start()
        for (i, cat) in categories.enumerated() {
            guard let size = measuredSizes[cat.id] else { continue }
            physics.launch(id: cat.id, width: size.width, height: size.height, delay: Double(i) * 0.06)
        }
    }
}

#Preview {
    Book()
}
