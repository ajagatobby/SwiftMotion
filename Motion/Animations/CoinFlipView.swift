//
//  CoinFlipView.swift
//  Motion
//
//  Ultra-realistic 3D coin flip — physics-based Y-axis spin with
//  precession, anticipation, parabolic arc, and haptic feedback.

import SwiftUI
import Combine
import CoreHaptics

// MARK: - Coin Front Face

private struct CoinFrontFace: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.90, blue: 0.35), location: 0.0),
                            .init(color: Color(red: 0.98, green: 0.82, blue: 0.28), location: 0.35),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.18), location: 0.65),
                            .init(color: Color(red: 0.82, green: 0.60, blue: 0.12), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.95, blue: 0.55), location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.85, blue: 0.30), location: 0.35),
                            .init(color: Color(red: 0.78, green: 0.56, blue: 0.10), location: 0.7),
                            .init(color: Color(red: 0.95, green: 0.80, blue: 0.30), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 14
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.65, green: 0.45, blue: 0.08).opacity(0.5),
                            Color.clear,
                            Color(red: 1.0, green: 0.92, blue: 0.50).opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .padding(13)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: 70
                    )
                )
                .padding(16)

            Text("$")
                .font(.system(size: 64, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.65, blue: 0.14),
                            Color(red: 0.68, green: 0.48, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.55, green: 0.38, blue: 0.05).opacity(0.5), radius: 0.5, x: 1, y: 1)
        }
        .compositingGroup()
    }
}

// MARK: - Coin Back Face

private struct CoinBackFace: View {
    var body: some View {
        ZStack {
            // Same gold base as front
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.90, blue: 0.35), location: 0.0),
                            .init(color: Color(red: 0.98, green: 0.82, blue: 0.28), location: 0.35),
                            .init(color: Color(red: 0.90, green: 0.70, blue: 0.18), location: 0.65),
                            .init(color: Color(red: 0.82, green: 0.60, blue: 0.12), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Same outer rim
            Circle()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.95, blue: 0.55), location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.85, blue: 0.30), location: 0.35),
                            .init(color: Color(red: 0.78, green: 0.56, blue: 0.10), location: 0.7),
                            .init(color: Color(red: 0.95, green: 0.80, blue: 0.30), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 14
                )

            // Same inner bevel
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.65, green: 0.45, blue: 0.08).opacity(0.5),
                            Color.clear,
                            Color(red: 1.0, green: 0.92, blue: 0.50).opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .padding(13)

            // Same specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: 70
                    )
                )
                .padding(16)

            // Different center symbol — star
            Image(systemName: "star.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.65, blue: 0.14),
                            Color(red: 0.68, green: 0.48, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(red: 0.55, green: 0.38, blue: 0.05).opacity(0.5), radius: 0.5, x: 1, y: 1)
        }
        .compositingGroup()
    }
}

// MARK: - 3D Coin

struct Coin3D: View {
    var spinY: Double     // Y-axis horizontal spin
    var tiltX: Double     // X-axis forward lean
    var precessionZ: Double // Z-axis precession drift

    private let coinSize: CGFloat = 250
    private let edgeLayers = 24
    private let layerSpacing: CGFloat = 1.3
    private let persp: CGFloat = 0.4

    private var halfThickness: CGFloat {
        CGFloat(edgeLayers) * layerSpacing / 2
    }

    private var showFront: Bool {
        cos(spinY) >= 0
    }

    var body: some View {
        ZStack {
            // Back face — zIndex 2 when visible so it renders ABOVE edge layers
            CoinBackFace()
                .frame(width: coinSize, height: coinSize)
                .scaleEffect(x: -1)
                .opacity(showFront ? 0 : 1)
                .rotation3DEffect(
                    .radians(spinY),
                    axis: (0, 1, 0),
                    anchor: .center,
                    anchorZ: -halfThickness,
                    perspective: persp
                )
                .zIndex(showFront ? 0 : 2)

            // Edge layers — always zIndex 1
            ForEach(0..<edgeLayers, id: \.self) { i in
                let z = CGFloat(i) * layerSpacing - halfThickness

                Circle()
                    .fill(edgeColor(for: i))
                    .frame(width: coinSize - 6, height: coinSize - 6)
                    .rotation3DEffect(
                        .radians(spinY),
                        axis: (0, 1, 0),
                        anchor: .center,
                        anchorZ: z,
                        perspective: persp
                    )
                    .zIndex(1)
            }

            // Front face — zIndex 2 when visible
            CoinFrontFace()
                .frame(width: coinSize, height: coinSize)
                .opacity(showFront ? 1 : 0)
                .rotation3DEffect(
                    .radians(spinY),
                    axis: (0, 1, 0),
                    anchor: .center,
                    anchorZ: halfThickness,
                    perspective: persp
                )
                .zIndex(showFront ? 2 : 0)
        }
        // Perspective tilt + precession on the parent
        .rotation3DEffect(.radians(tiltX), axis: (1, 0, 0), perspective: 0.3)
        .rotation3DEffect(.radians(precessionZ), axis: (0, 0, 1), perspective: 0)
    }

    private func edgeColor(for layer: Int) -> Color {
        // All bright gold — no dark bands that cause black artifacts
        switch layer % 3 {
        case 0:  Color(red: 0.92, green: 0.75, blue: 0.28)
        case 1:  Color(red: 0.85, green: 0.65, blue: 0.22)
        default: Color(red: 0.88, green: 0.70, blue: 0.25)
        }
    }
}

// MARK: - Haptic Engine

private class CoinHaptics {
    static let shared = CoinHaptics()

    private var engine: CHHapticEngine?
    private let launchImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let landImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let resultFeedback = UINotificationFeedbackGenerator()

    func prepare() {
        launchImpact.prepare()
        landImpact.prepare()
        resultFeedback.prepare()
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {}
    }

    func playLaunch() {
        launchImpact.impactOccurred(intensity: 0.9)
    }

    func playLand() {
        landImpact.impactOccurred(intensity: 1.0)
    }

    func playResult() {
        resultFeedback.notificationOccurred(.success)
    }

    func playSpinTicks(rotations: Int, duration: Double) {
        guard let engine else { return }
        var events: [CHHapticEvent] = []
        let tickCount = rotations * 2

        for i in 0..<tickCount {
            let progress = Double(i) / Double(tickCount)
            // Exponential timing — ticks cluster at the start (fast spin)
            let time = duration * (1 - pow(1 - progress, 2.2))
            let intensity = Float(max(0.1, 1.0 - progress * 0.8))
            let sharpness = Float(0.2 + (1.0 - progress) * 0.4)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }
}

// MARK: - Physics Simulation State

struct CoinPhysics {
    enum Phase { case idle, anticipation, flight, bouncing, settling, done }

    var phase: Phase = .idle

    // Vertical (meters) — y=0 is resting position, positive = up
    var y: Double = 0
    var vy: Double = 0

    // Horizontal drift (meters)
    var dx: Double = 0
    var vx: Double = 0

    // Spin (radians)
    var angle: Double = 0
    var omega: Double = 0          // angular velocity (rad/s)
    var angularDrag: Double = 0.8  // exponential decay in flight

    // Tilt (radians)
    var tiltX: Double = 0.25
    var tiltVel: Double = 0

    // Precession (radians)
    var precZ: Double = 0
    var precVel: Double = 0

    // Scale (for anticipation squeeze)
    var scale: Double = 1.0

    // Bounce tracking
    var bounceCount: Int = 0
    var restitution: Double = 0.38
    var spinFriction: Double = 0.55  // spin retained per bounce

    // Settle tracking
    var settleElapsed: Double = 0
    var settleDuration: Double = 0.8

    // Timing
    var elapsed: Double = 0
    var anticipationDuration: Double = 0.1

    // Result
    enum CoinResult { case heads, tails, tied }
    var landsHeads: Bool = true
    var finalAngle: Double = 0  // target angle for face-showing at rest

    var coinResult: CoinResult {
        let cosA = cos(angle)
        if abs(cosA) < 0.3 { return .tied }  // edge-on
        return cosA >= 0 ? .heads : .tails
    }

    // Events (consumed by the view for haptics/sounds)
    var justLaunched = false
    var justBounced = false
    var justSettled = false

    // Constants
    private let g: Double = 9.81
    private let restTiltX: Double = 0.25

    // Pixels per meter for rendering
    static let ppm: Double = 280.0

    var yPixels: CGFloat { CGFloat(-y * Self.ppm) }
    var dxPixels: CGFloat { CGFloat(dx * Self.ppm) }

    // MARK: - Launch

    mutating func launch(heads: Bool) {
        landsHeads = heads
        phase = .anticipation
        elapsed = 0
        bounceCount = 0
        justLaunched = false
        justBounced = false
        justSettled = false
    }

    // MARK: - Step

    mutating func step(dt: Double) {
        guard phase != .idle && phase != .done else { return }
        elapsed += dt

        // Clear one-frame events
        justLaunched = false
        justBounced = false
        justSettled = false

        switch phase {
        case .anticipation:
            // Slight downward dip + squeeze over 0.1s
            let t = min(elapsed / anticipationDuration, 1.0)
            y = -0.01 * sin(t * .pi) // small dip
            scale = 1.0 - 0.04 * sin(t * .pi)
            if elapsed >= anticipationDuration {
                launchCoin()
            }

        case .flight:
            stepFlight(dt: dt)

        case .bouncing:
            stepBouncing(dt: dt)

        case .settling:
            stepSettling(dt: dt)

        default:
            break
        }
    }

    // MARK: - Flight phase

    private mutating func launchCoin() {
        phase = .flight
        elapsed = 0

        // Random toss height 0.35–0.55 meters
        let height = Double.random(in: 0.35...0.55)
        vy = sqrt(2 * g * height)
        y = 0
        scale = 1.0

        // Horizontal drift
        vx = Double.random(in: -0.15...0.15)
        dx = 0

        // Spin: solve for omega0 to achieve desired rotations
        let rotations = Double.random(in: 5...8)
        let flightTime = 2 * vy / g
        // Target angle is absolute — includes current angle as base
        let deltaAngle = rotations * 2 * .pi + (landsHeads ? 0 : .pi)
        finalAngle = angle + deltaAngle
        // With exponential drag: totalAngle = omega0/drag * (1 - exp(-drag*T))
        let drag = angularDrag
        omega = deltaAngle * drag / (1 - exp(-drag * flightTime))

        // Tilt forward to see spin
        tiltVel = 1.5
        tiltX = 0.25

        // Precession
        precVel = Double.random(in: -0.8...0.8)

        justLaunched = true
    }

    private mutating func stepFlight(dt: Double) {
        // Gravity
        vy -= g * dt
        y += vy * dt

        // Horizontal drift (slight air drag)
        dx += vx * dt
        vx *= (1 - 0.5 * dt) // gentle drag

        // Spin with exponential drag
        omega *= exp(-angularDrag * dt)
        angle += omega * dt

        // Tilt eases toward show-spin angle (0.45)
        let tiltTarget = 0.45
        let tiltAccel = (tiltTarget - tiltX) * 20 - tiltVel * 5
        tiltVel += tiltAccel * dt
        tiltX += tiltVel * dt

        // Precession
        precZ += precVel * dt
        precVel *= (1 - 0.3 * dt)

        // Scale: slightly bigger at apex (closer to camera)
        let normalizedHeight = max(0, y) / 0.55
        scale = 1.0 + 0.06 * normalizedHeight

        // Landing
        if y <= 0 && vy < 0 {
            y = 0
            phase = .bouncing
            vy = -vy * restitution
            omega *= spinFriction
            bounceCount = 1
            justBounced = true
        }
    }

    // MARK: - Bouncing phase

    private mutating func stepBouncing(dt: Double) {
        vy -= g * dt
        y += vy * dt

        // Steer spin toward final angle (gentle during bouncing)
        let angleDiff = finalAngle - angle
        let steer = angleDiff * 6.0 - omega * 2.0
        omega += steer * dt
        angle += omega * dt

        // Drift decays on bounces
        dx += vx * dt
        vx *= (1 - 5.0 * dt)

        // Scale snaps back
        scale = 1.0

        // Tilt starts returning
        let tiltAccel = (restTiltX - tiltX) * 30 - tiltVel * 8
        tiltVel += tiltAccel * dt
        tiltX += tiltVel * dt

        // Precession damps
        precVel *= (1 - 3.0 * dt)
        precZ += precVel * dt

        if y <= 0 && vy < 0 {
            bounceCount += 1
            if bounceCount > 3 || abs(vy * restitution) < 0.15 {
                // Done bouncing → settle
                y = 0
                vy = 0
                vx = 0
                phase = .settling
                settleElapsed = 0
            } else {
                y = 0
                vy = -vy * restitution
                omega *= spinFriction
                justBounced = true
            }
        }
    }

    // MARK: - Settling phase (Euler's disc wobble)

    private mutating func stepSettling(dt: Double) {
        settleElapsed += dt
        let progress = min(settleElapsed / settleDuration, 1.0)

        // Euler's disc: wobble frequency INCREASES as coin settles
        let timeToEnd = max(0.01, 1.0 - progress)
        let wobbleFreq = 15.0 / pow(timeToEnd, 0.33)
        let wobbleAmp = 0.06 * pow(timeToEnd, 0.5)

        tiltX = restTiltX + wobbleAmp * sin(wobbleFreq * settleElapsed)

        // Steer angle toward finalAngle — strong spring so coin shows face
        let angleDiff = finalAngle - angle
        let steerForce = angleDiff * 40.0 - omega * 10.0
        omega += steerForce * dt
        angle += omega * dt

        // Precession decays
        precZ *= (1 - 6.0 * dt)

        // Drift final settle
        dx *= (1 - 8.0 * dt)

        scale = 1.0

        if progress >= 1.0 {
            angle = finalAngle  // snap exact
            tiltX = restTiltX
            precZ = 0
            dx = 0
            omega = 0
            phase = .done
            justSettled = true
        }
    }
}

// MARK: - Physics Engine (reference type for CADisplayLink)

@MainActor
final class CoinPhysicsEngine: ObservableObject {
    @Published var sim = CoinPhysics()
    @Published var isFlipping = false
    @Published var result: String = "Tap to Flip"
    @Published var resultOpacity: Double = 1.0
    @Published var resultScale: Double = 1.0
    @Published var resultBlur: Double = 0
    @Published var headsCount: Int = 0
    @Published var tailsCount: Int = 0
    @Published var tiedCount: Int = 0

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    // Event flags
    private var launchSoundPlayed = false
    private var landSoundPlayed = false
    private var resultDone = false

    private let haptics = CoinHaptics.shared
    private let sounds = CoinSoundEngine.shared

    func prepare() {
        haptics.prepare()
        sounds.setup()
    }

    func flip() {
        guard !isFlipping else { return }
        isFlipping = true
        launchSoundPlayed = false
        landSoundPlayed = false
        resultDone = false

        // Fade out old result
        withAnimation(.easeOut(duration: 0.2)) {
            resultOpacity = 0
            resultScale = 0.8
            resultBlur = 6
        }

        // Show "Flipping..." after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.result = "Flipping..."
            withAnimation(.easeIn(duration: 0.15)) {
                self.resultOpacity = 0.5
                self.resultScale = 0.95
                self.resultBlur = 0
            }
        }

        haptics.prepare()
        sim.launch(heads: Bool.random())
        startLoop()
    }

    private func startLoop() {
        stopLoop()
        lastTimestamp = 0

        let target = DisplayLinkTarget { [weak self] link in
            Task { @MainActor in
                self?.tick(link)
            }
        }
        // prevent deallocation
        objc_setAssociatedObject(self, "displayLinkTarget", target, .OBJC_ASSOCIATION_RETAIN)

        link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.update(_:)))
        link?.add(to: .main, forMode: .common)
    }

    private func stopLoop() {
        link?.invalidate()
        link = nil
    }

    private func tick(_ displayLink: CADisplayLink) {
        let now = displayLink.timestamp
        if lastTimestamp == 0 { lastTimestamp = now }
        let dt = min(now - lastTimestamp, 1.0 / 30.0)
        lastTimestamp = now

        sim.step(dt: dt)

        // Haptics/sounds on physics events
        if sim.justLaunched && !launchSoundPlayed {
            launchSoundPlayed = true
            haptics.playLaunch()
            sounds.playLaunchChime()
            sounds.playSpinShimmer(duration: 1.8)
        }

        if sim.justBounced {
            haptics.playLand()
            if !landSoundPlayed {
                landSoundPlayed = true
                sounds.playLandDing()
            }
        }

        if sim.phase == .done && !resultDone {
            resultDone = true
            stopLoop()

            // Fade out "Flipping..."
            withAnimation(.easeOut(duration: 0.15)) {
                resultOpacity = 0
                resultScale = 0.7
            }

            // Pop in the result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                switch self.sim.coinResult {
                case .heads:
                    self.headsCount += 1
                    self.result = "HEADS"
                case .tails:
                    self.tailsCount += 1
                    self.result = "TAILS"
                case .tied:
                    self.tiedCount += 1
                    self.result = "EDGE — TIE!"
                }

                // Start from big + transparent, spring to normal
                self.resultScale = 1.3
                self.resultBlur = 4
                self.resultOpacity = 0

                withAnimation(.interpolatingSpring(mass: 0.6, stiffness: 200, damping: 12, initialVelocity: 0)) {
                    self.resultOpacity = 1.0
                    self.resultScale = 1.0
                    self.resultBlur = 0
                }

                self.isFlipping = false
                self.haptics.playResult()
                self.sounds.playResultChord()
            }
        }
    }
}

// CADisplayLink requires an @objc target
private class DisplayLinkTarget {
    let callback: (CADisplayLink) -> Void
    init(_ callback: @escaping (CADisplayLink) -> Void) {
        self.callback = callback
    }
    @objc func update(_ link: CADisplayLink) {
        callback(link)
    }
}

// MARK: - Main Coin Flip View

struct CoinFlipView: View {
    @StateObject private var engine = CoinPhysicsEngine()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            // Result label — positioned absolutely at top
            VStack {
                Text(engine.result)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.95),
                                .white.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.4).opacity(0.2), radius: 12, y: 2)
                    .opacity(engine.resultOpacity)
                    .scaleEffect(engine.resultScale)
                    .blur(radius: engine.resultBlur)
                    .padding(.top, 100)

                Spacer()
            }

            // Coin + shadow — centered
            VStack {
                Spacer()

                ZStack {
                    coinShadow

                    Coin3D(
                        spinY: engine.sim.angle,
                        tiltX: engine.sim.tiltX,
                        precessionZ: engine.sim.precZ
                    )
                    .offset(x: engine.sim.dxPixels, y: engine.sim.yPixels)
                    .scaleEffect(engine.sim.scale)
                }
                .frame(height: 380)

                Spacer()
            }

            // Flip button — positioned absolutely at bottom
            VStack {
                Spacer()
                flipButton
                    .padding(.bottom, 60)
            }
        }
        .onAppear { engine.prepare() }
    }

    // MARK: - Shadow

    private var coinShadow: some View {
        let p = Double(abs(engine.sim.yPixels)) / 170.0

        return ZStack {
            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(0.22), .black.opacity(0.08), .clear],
                    center: .center, startRadius: 20, endRadius: 140
                ))
                .frame(width: 260 - 60 * p, height: 40 - 15 * p)
                .blur(radius: 20 + 12 * p)
                .offset(x: 12 + engine.sim.dxPixels * 0.3, y: 170)
                .opacity(max(0, 1 - p * 0.6))

            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(0.38), .black.opacity(0.12), .clear],
                    center: .center, startRadius: 10, endRadius: 95
                ))
                .frame(width: 190 - 50 * p, height: 30 - 10 * p)
                .blur(radius: 10 + 8 * p)
                .offset(x: 10 + engine.sim.dxPixels * 0.3, y: 165)
                .opacity(max(0, 1 - p * 0.7))

            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.25), .clear],
                    center: .center, startRadius: 3, endRadius: 55
                ))
                .frame(width: 130 - 40 * p, height: 14 - 6 * p)
                .blur(radius: 3 + 5 * p)
                .offset(x: 6 + engine.sim.dxPixels * 0.3, y: 160)
                .opacity(max(0, 1 - p * 1.2))

            Ellipse()
                .fill(Color(red: 0.65, green: 0.50, blue: 0.15).opacity(0.06))
                .frame(width: 90, height: 8)
                .blur(radius: 6)
                .offset(x: 6 + engine.sim.dxPixels * 0.3, y: 158)
                .opacity(max(0, 1 - p * 1.5))
        }
    }

    // MARK: - Flip Button

    private var flipButton: some View {
        Button {
            engine.flip()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .rotationEffect(.degrees(engine.isFlipping ? 360 : 0))
                    .animation(
                        engine.isFlipping
                            ? .linear(duration: 0.5).repeatForever(autoreverses: false)
                            : .default,
                        value: engine.isFlipping
                    )
                Text("FLIP")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(3)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.92, blue: 0.50),
                        Color(red: 0.88, green: 0.70, blue: 0.28)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 44)
            .padding(.vertical, 16)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.90, green: 0.75, blue: 0.32).opacity(0.4),
                                        Color(red: 0.60, green: 0.42, blue: 0.12).opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
        }
        .disabled(engine.isFlipping)
        .opacity(engine.isFlipping ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: engine.isFlipping)
    }
}

#Preview {
    CoinFlipView()
        .preferredColorScheme(.dark)
}
