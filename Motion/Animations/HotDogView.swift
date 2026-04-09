
import SwiftUI
import CoreMotion
import AudioToolbox

// MARK: - Wiggle Bone (Spring-based follow-the-leader)

struct Bone {
    var x: CGFloat
    var y: CGFloat
    var goalX: CGFloat   // where this bone wants to be (restLength behind parent)
    var goalY: CGFloat
    var vx: CGFloat = 0  // spring velocity
    var vy: CGFloat = 0
}

@Observable
final class HotDogPhysics {
    var bones: [Bone] = []

    private var displayLink: CADisplayLink?
    private var motionManager: CMMotionManager?

    let boneCount = 12
    let restLength: CGFloat = 20

    // Damped harmonic oscillator params (from wiggle bone reference)
    let stiffness: CGFloat = 400     // spring constant k
    let mass: CGFloat = 1.0          // mass m
    let dampingRatio: CGFloat = 0.6  // zeta (< 1 = underdamped = jiggly)

    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var targetX: CGFloat = 0
    var targetY: CGFloat = 0
    var isDragging = false

    // Derived
    private var omega0: CGFloat { sqrt(stiffness / mass) }          // natural frequency
    private var dampingCoeff: CGFloat { 2 * dampingRatio * omega0 * mass }  // damping c

    func start(center: CGPoint) {
        guard bones.isEmpty else { return }

        let totalLen = CGFloat(boneCount - 1) * restLength
        let startX = center.x - totalLen / 2
        bones = (0..<boneCount).map { i in
            let x = startX + CGFloat(i) * restLength
            return Bone(x: x, y: center.y, goalX: x, goalY: center.y)
        }
        targetX = center.x
        targetY = center.y

        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link

        let mm = CMMotionManager()
        motionManager = mm
        if mm.isAccelerometerAvailable {
            mm.accelerometerUpdateInterval = 1.0 / 60.0
            mm.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.tiltX = CGFloat(data.acceleration.x)
                self.tiltY = CGFloat(-data.acceleration.y)
            }
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
    }

    @objc private func tick() {
        let dt: CGFloat = 1.0 / 60.0
        let c = dampingCoeff
        let k = stiffness
        let m = mass

        // ── Root bone: follows drag or springs to center ──
        if isDragging {
            bones[0].x = targetX
            bones[0].y = targetY
            bones[0].vx = 0; bones[0].vy = 0
        } else {
            let cx = targetX + tiltX * 40
            let cy = targetY + tiltY * 40
            // Spring the root back gently
            let fx = k * 0.3 * (cx - bones[0].x) - c * 0.5 * bones[0].vx
            let fy = k * 0.3 * (cy - bones[0].y) - c * 0.5 * bones[0].vy
            bones[0].vx += fx / m * dt
            bones[0].vy += fy / m * dt
            bones[0].x += bones[0].vx * dt
            bones[0].y += bones[0].vy * dt
        }

        // ── Follower bones: each springs toward a point that is
        //    restLength behind its parent (along parent→child direction) ──
        for i in 1..<boneCount {
            let px = bones[i - 1].x
            let py = bones[i - 1].y

            // Direction from parent to current bone
            var dx = bones[i].x - px
            var dy = bones[i].y - py
            var dist = sqrt(dx * dx + dy * dy)

            // If overlapping, push apart
            if dist < 0.001 {
                dx = restLength; dy = 0; dist = restLength
            }

            // The goal: exactly restLength behind parent
            let nx = dx / dist
            let ny = dy / dist
            bones[i].goalX = px + nx * restLength
            bones[i].goalY = py + ny * restLength

            // Damped spring force: F = -k(x - goal) - c*v
            let springFx = -k * (bones[i].x - bones[i].goalX) - c * bones[i].vx
            let springFy = -k * (bones[i].y - bones[i].goalY) - c * bones[i].vy

            // Tilt force
            let tiltFx = tiltX * 300
            let tiltFy = tiltY * 300

            bones[i].vx += (springFx + tiltFx) / m * dt
            bones[i].vy += (springFy + tiltFy) / m * dt
            bones[i].x += bones[i].vx * dt
            bones[i].y += bones[i].vy * dt

            // Hard clamp: never more than 1.3x restLength from parent
            let newDx = bones[i].x - px
            let newDy = bones[i].y - py
            let newDist = sqrt(newDx * newDx + newDy * newDy)
            let maxDist = restLength * 1.3
            if newDist > maxDist {
                bones[i].x = px + newDx / newDist * maxDist
                bones[i].y = py + newDy / newDist * maxDist
            }
            // Also min distance
            let minDist = restLength * 0.7
            if newDist < minDist && newDist > 0.001 {
                bones[i].x = px + newDx / newDist * minDist
                bones[i].y = py + newDy / newDist * minDist
            }
        }
    }
}

// MARK: - Catmull-Rom

private func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
    let t2 = t * t, t3 = t2 * t
    let x = 0.5 * ((2*p1.x) + (-p0.x+p2.x)*t + (2*p0.x-5*p1.x+4*p2.x-p3.x)*t2 + (-p0.x+3*p1.x-3*p2.x+p3.x)*t3)
    let y = 0.5 * ((2*p1.y) + (-p0.y+p2.y)*t + (2*p0.y-5*p1.y+4*p2.y-p3.y)*t2 + (-p0.y+3*p1.y-3*p2.y+p3.y)*t3)
    return CGPoint(x: x, y: y)
}

private func catmullRomTangent(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
    let t2 = t * t
    let x = 0.5 * ((-p0.x+p2.x) + (4*p0.x-10*p1.x+8*p2.x-2*p3.x)*t + (-3*p0.x+9*p1.x-9*p2.x+3*p3.x)*t2)
    let y = 0.5 * ((-p0.y+p2.y) + (4*p0.y-10*p1.y+8*p2.y-2*p3.y)*t + (-3*p0.y+9*p1.y-9*p2.y+3*p3.y)*t2)
    return CGPoint(x: x, y: y)
}

// MARK: - Hot Dog View

struct HotDogView: View {
    @State private var physics = HotDogPhysics()
    @State private var screenSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.93, blue: 0.90).ignoresSafeArea()

            Canvas { ctx, size in
                guard physics.bones.count >= 2 else { return }
                drawHotDog(ctx: &ctx, size: size)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !physics.isDragging {
                            AudioServicesPlaySystemSound(1104)
                        }
                        physics.isDragging = true
                        physics.targetX = value.location.x
                        physics.targetY = value.location.y
                    }
                    .onEnded { _ in
                        physics.isDragging = false
                        physics.targetX = screenSize.width / 2
                        physics.targetY = screenSize.height / 2
                    }
            )
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.3), trigger: physics.isDragging)

            // Instructions
            VStack {
                Spacer()
                Text("drag to wiggle · tilt device")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.3))
                    .padding(.bottom, 50)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    screenSize = geo.size
                    physics.start(center: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                }
            }
        )
        .onDisappear { physics.stop() }
    }

    // MARK: - Draw Hot Dog (stroke-based — can't self-intersect)

    private func splinePath() -> Path {
        let pts = physics.bones.map { CGPoint(x: $0.x, y: $0.y) }
        guard pts.count >= 2 else { return Path() }

        var path = Path()
        let N = 40

        for s in 0...N {
            let gT = CGFloat(s) / CGFloat(N)
            let segF = gT * CGFloat(pts.count - 1)
            let seg = min(Int(segF), pts.count - 2)
            let lT = segF - CGFloat(seg)
            let p0 = pts[max(0, seg - 1)]
            let p1 = pts[seg]
            let p2 = pts[min(pts.count - 1, seg + 1)]
            let p3 = pts[min(pts.count - 1, seg + 2)]
            let pt = catmullRom(p0, p1, p2, p3, lT)
            if s == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }

    private func drawHotDog(ctx: inout GraphicsContext, size: CGSize) {
        let spine = splinePath()
        let roundCap = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)

        // ── 1. Shadow ──
        ctx.drawLayer { s in
            s.addFilter(.blur(radius: 12))
            s.translateBy(x: 0, y: 6)
            s.stroke(spine, with: .color(.black.opacity(0.2)),
                     style: StrokeStyle(lineWidth: 44, lineCap: .round, lineJoin: .round))
        }

        // ── 2. Bun (outer) ──
        ctx.stroke(spine, with: .color(Color(red: 0.88, green: 0.72, blue: 0.45)),
                   style: StrokeStyle(lineWidth: 42, lineCap: .round, lineJoin: .round))

        // ── 3. Bun lighter top ──
        ctx.stroke(spine, with: .color(Color(red: 0.95, green: 0.82, blue: 0.55)),
                   style: StrokeStyle(lineWidth: 38, lineCap: .round, lineJoin: .round))

        // ── 4. Bun split (dark inner crease) ──
        ctx.stroke(spine, with: .color(Color(red: 0.62, green: 0.45, blue: 0.28).opacity(0.6)),
                   style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))

        // ── 5. Sausage ──
        ctx.stroke(spine, with: .color(Color(red: 0.72, green: 0.28, blue: 0.12)),
                   style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))

        // ── 6. Sausage highlight ──
        ctx.stroke(spine, with: .color(Color(red: 0.88, green: 0.48, blue: 0.22)),
                   style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))

        ctx.stroke(spine, with: .color(Color(red: 0.95, green: 0.60, blue: 0.30).opacity(0.4)),
                   style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

        // ── 7. Mustard squiggle ──
        let pts = physics.bones.map { CGPoint(x: $0.x, y: $0.y) }
        var mustard = Path()
        let mN = 30
        for s in 0...mN {
            let gT = CGFloat(s) / CGFloat(mN)
            let segF = gT * CGFloat(pts.count - 1)
            let seg = min(Int(segF), pts.count - 2)
            let lT = segF - CGFloat(seg)
            let p0 = pts[max(0, seg - 1)]
            let p1 = pts[seg]
            let p2 = pts[min(pts.count - 1, seg + 1)]
            let p3 = pts[min(pts.count - 1, seg + 2)]
            let pt = catmullRom(p0, p1, p2, p3, lT)
            let tg = catmullRomTangent(p0, p1, p2, p3, lT)
            let len = sqrt(tg.x * tg.x + tg.y * tg.y)
            let nx = len > 0.001 ? -tg.y / len : 0
            let ny = len > 0.001 ? tg.x / len : 0
            let wiggle = sin(gT * .pi * 6) * 5
            let mp = CGPoint(x: pt.x + nx * wiggle, y: pt.y + ny * wiggle)
            if s == 0 { mustard.move(to: mp) } else { mustard.addLine(to: mp) }
        }
        ctx.stroke(mustard, with: .color(Color(red: 0.95, green: 0.82, blue: 0.10)),
                   style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        // ── 8. Sesame seeds ──
        for seedT in [0.15, 0.3, 0.5, 0.7, 0.85] as [CGFloat] {
            let segF = seedT * CGFloat(pts.count - 1)
            let seg = min(Int(segF), pts.count - 2)
            let lT = segF - CGFloat(seg)
            let p1 = pts[seg], p2 = pts[min(pts.count - 1, seg + 1)]
            let sp = CGPoint(x: p1.x + (p2.x - p1.x) * lT, y: p1.y + (p2.y - p1.y) * lT)
            let tg = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            let len = sqrt(tg.x * tg.x + tg.y * tg.y)
            let nx = len > 0.001 ? -tg.y / len : 0
            let ny = len > 0.001 ? tg.x / len : 0
            let seedP = CGPoint(x: sp.x + nx * 16, y: sp.y + ny * 16)
            let angle = atan2(tg.y, tg.x)

            ctx.drawLayer { sc in
                sc.translateBy(x: seedP.x, y: seedP.y)
                sc.rotate(by: .radians(angle + .pi * 0.25))
                sc.fill(Ellipse().path(in: CGRect(x: -3.5, y: -1.5, width: 7, height: 3)),
                        with: .color(Color(red: 0.96, green: 0.93, blue: 0.82)))
            }
        }
    }
}

#Preview {
    HotDogView()
}
