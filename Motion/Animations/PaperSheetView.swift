
import SwiftUI
import Combine
import CoreMotion
import AVFoundation

// MARK: - Gyroscope

private class PaperMotion: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let m, let self else { return }
            self.pitch += (m.attitude.pitch - self.pitch) * 0.12
            self.roll += (m.attitude.roll - self.roll) * 0.12
        }
    }
    deinit { manager.stopDeviceMotionUpdates() }
}

// MARK: - Paper Sheet View

struct PaperSheetView: View {
    @StateObject private var motion = PaperMotion()

    // Corner fold
    @State private var cornerPeel: CGFloat = 0

    // Lift
    @State private var liftScale: CGFloat = 1.0
    @State private var shadowSize: CGFloat = 8
    @State private var isLifted = false

    // Press effect
    @State private var rippleTouchPoint: CGPoint = .zero
    @State private var rippleTime: CGFloat = 0
    @State private var rippleIntensity: CGFloat = 0
    @State private var rippleTimer: Timer?
    @State private var paperSize: CGSize = CGSize(width: 350, height: 350)

    // Micro animations
    @State private var appeared = false
    @State private var entranceOffset: CGFloat = 60
    @State private var entranceOpacity: CGFloat = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var tapSquash: CGFloat = 1.0
    @State private var tapStretch: CGFloat = 1.0
    @State private var visibleLines: Int = 0
    @State private var dragTiltX: CGFloat = 0
    @State private var dragTiltY: CGFloat = 0

    // 3D Button state
    @State private var buttonPressed = false
    @State private var isFolded = false
    @State private var buttonAppeared = false
    @State private var foldWobble: CGFloat = 0
    @State private var iconRotation: CGFloat = 0

    // Burn state
    @State private var isBurning = false
    @State private var burnProgress: CGFloat = 0
    @State private var burnTouchPoint: CGPoint = .zero
    @State private var burnTime: CGFloat = 0
    @State private var burnTimer: Timer?
    @State private var burnPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            deskSurface

            VStack {
                Spacer()

                paper
                    .padding(.horizontal, 24)

                Spacer()

                HStack(spacing: 14) {
                    foldButton
                    burnButton
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .onAppear { triggerEntrance() }
    }

    // MARK: - 3D Duolingo-style Button

    private func performFold() {
        isFolded.toggle()
        FireSoundEngine.shared.playFoldSound()

        if isFolded {
            // Phase 1: Paper tilts slightly toward the corner
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                foldWobble = -1.5
            }
            // Phase 2: Corner peels with wobble settling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                    cornerPeel = 0.6
                    shadowSize = 18
                    foldWobble = 0
                }
            }
            // Icon spins
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                iconRotation = 180
            }
        } else {
            // Unfold with a little bounce
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                cornerPeel = 0
                shadowSize = 8
                foldWobble = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    foldWobble = 0
                }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                iconRotation = 0
            }
        }
    }

    @State private var buttonScaleX: CGFloat = 1
    @State private var buttonScaleY: CGFloat = 1

    private var foldButton: some View {
        ZStack {
            // Bottom 3D edge
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.72, green: 0.68, blue: 0.62))
                .padding(.horizontal, 2)
                .offset(y: buttonPressed ? 2 : 5)

            // Top face
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.97, blue: 0.94),
                            Color(red: 0.94, green: 0.92, blue: 0.88),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear, .black.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                )
                .offset(y: buttonPressed ? 3 : 0)

            // Content
            HStack(spacing: 10) {
                Image(systemName: isFolded ? "arrow.uturn.backward" : "doc.plaintext")
                    .font(.system(size: 16, weight: .bold))
                    .rotationEffect(.degrees(iconRotation))
                    .contentTransition(.symbolEffect(.replace.downUp))

                Text(isFolded ? "Unfold" : "Fold Corner")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.15))
            .offset(y: buttonPressed ? 3 : 0)
        }
        .frame(height: 52)
        // Squash-stretch on press
        .scaleEffect(x: buttonScaleX, y: buttonScaleY)
        // Entrance
        .scaleEffect(buttonAppeared ? 1 : 0.6)
        .opacity(buttonAppeared ? 1 : 0)
        .onTapGesture {
            // Press down with squash
            withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                buttonPressed = true
                buttonScaleX = 1.04
                buttonScaleY = 0.92
            }

            // Release with stretch + overshoot
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    buttonPressed = false
                    buttonScaleX = 0.97
                    buttonScaleY = 1.06
                }
            }

            // Settle back to normal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    buttonScaleX = 1
                    buttonScaleY = 1
                }
            }

            // Trigger fold after the press animation
            FireSoundEngine.shared.playButtonClick()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                performFold()
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: isFolded)
    }

    // MARK: - Burn Button

    @State private var burnButtonPressed = false
    @State private var burnButtonScaleX: CGFloat = 1
    @State private var burnButtonScaleY: CGFloat = 1

    private var burnButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.55, green: 0.20, blue: 0.12))
                .offset(y: burnButtonPressed ? 2 : 5)
                .padding(.horizontal, 2)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.85, green: 0.35, blue: 0.15),
                            Color(red: 0.72, green: 0.25, blue: 0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .offset(y: burnButtonPressed ? 3 : 0)

            HStack(spacing: 8) {
                Image(systemName: isBurning ? "arrow.counterclockwise" : "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .contentTransition(.symbolEffect(.replace.downUp))

                Text(isBurning ? "Reset" : "Burn")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(.white)
            .offset(y: burnButtonPressed ? 3 : 0)
        }
        .frame(height: 52)
        .scaleEffect(x: burnButtonScaleX, y: burnButtonScaleY)
        .scaleEffect(buttonAppeared ? 1 : 0.6)
        .opacity(buttonAppeared ? 1 : 0)
        .onTapGesture {
            // Squash
            withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                burnButtonPressed = true
                burnButtonScaleX = 1.04
                burnButtonScaleY = 0.92
            }
            // Stretch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    burnButtonPressed = false
                    burnButtonScaleX = 0.97
                    burnButtonScaleY = 1.06
                }
            }
            // Settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    burnButtonScaleX = 1
                    burnButtonScaleY = 1
                }
            }
            // Action
            FireSoundEngine.shared.playButtonClick()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if isBurning {
                    resetPaper()
                } else {
                    startBurn()
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: isBurning)
    }

    private func startBurn() {
        isBurning = true
        burnProgress = 0
        burnTime = 0
        burnTouchPoint = CGPoint(x: paperSize.width / 2, y: paperSize.height / 2)

        // Synthesized fire crackle
        FireSoundEngine.shared.startFire()

        burnTimer?.invalidate()
        burnTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            burnTime += 1.0 / 60.0
            burnProgress = min(1.0, burnProgress + 1.0 / 60.0 / 4.0)

            // Fade sound with burn progress
            FireSoundEngine.shared.setIntensity(Float(1.0 - burnProgress * 0.5))

            if burnProgress >= 1.0 {
                timer.invalidate()
                burnTimer = nil
                FireSoundEngine.shared.stopFire()
            }
        }
    }

    private func resetPaper() {
        burnTimer?.invalidate()
        burnTimer = nil
        FireSoundEngine.shared.stopFire()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isBurning = false
            burnProgress = 0
            burnTime = 0
        }
    }

    // MARK: - Entrance

    private func triggerEntrance() {
        guard !appeared else { return }
        appeared = true

        // Paper slides up with spring
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.2)) {
            entranceOffset = 0
            entranceOpacity = 1
        }

        // Stagger text lines
        for i in 0...paperLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.06) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    visibleLines = i + 1
                }
            }
        }

        // Button entrance — slides up after paper lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                buttonAppeared = true
            }
        }

        // Start breathing after entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathScale = 1.005
            }
        }
    }

    // MARK: - Desk

    private var deskSurface: some View {
        ZStack {
            Color(red: 0.18, green: 0.15, blue: 0.13)
                .ignoresSafeArea()

            RadialGradient(
                colors: [.clear, .black.opacity(0.4)],
                center: .center,
                startRadius: 150,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Paper

    private var paper: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fd = cornerPeel * min(w, h) * 0.65

            Canvas { ctx, size in
                let sw = size.width, sh = size.height
                let d = cornerPeel * min(sw, sh) * 0.65

                // Paper body
                var paperPath = Path()
                paperPath.move(to: .zero)
                paperPath.addLine(to: CGPoint(x: sw, y: 0))
                if d > 1 {
                    paperPath.addLine(to: CGPoint(x: sw, y: sh - d))
                    paperPath.addLine(to: CGPoint(x: sw - d, y: sh))
                } else {
                    paperPath.addLine(to: CGPoint(x: sw, y: sh))
                }
                paperPath.addLine(to: CGPoint(x: 0, y: sh))
                paperPath.closeSubpath()

                ctx.fill(paperPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.94),
                        Color(red: 0.95, green: 0.93, blue: 0.88),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: sw, y: sh)
                ))

                // Fold
                if d > 1 {
                    let foldTop = CGPoint(x: sw, y: sh - d)
                    let foldLeft = CGPoint(x: sw - d, y: sh)
                    let shadowWidth: CGFloat = min(d * 0.3, 20)
                    let nx: CGFloat = 1 / sqrt(2), ny: CGFloat = 1 / sqrt(2)

                    for i in 0..<Int(shadowWidth) {
                        let t = CGFloat(i) / shadowWidth
                        let off = CGFloat(i)
                        var line = Path()
                        line.move(to: CGPoint(x: foldTop.x - nx * off, y: foldTop.y - ny * off))
                        line.addLine(to: CGPoint(x: foldLeft.x - nx * off, y: foldLeft.y - ny * off))
                        ctx.stroke(line, with: .color(.black.opacity(0.12 * (1 - t) * (1 - t))), lineWidth: 1.5)
                    }

                    let mirrorCorner = CGPoint(x: sw - d, y: sh - d)
                    var flapPath = Path()
                    flapPath.move(to: foldTop)
                    flapPath.addLine(to: mirrorCorner)
                    flapPath.addLine(to: foldLeft)
                    flapPath.closeSubpath()

                    ctx.fill(flapPath, with: .color(Color(red: 0.93, green: 0.91, blue: 0.88)))
                    ctx.fill(flapPath, with: .linearGradient(
                        Gradient(colors: [.black.opacity(0.08), .black.opacity(0.01)]),
                        startPoint: CGPoint(x: (foldTop.x + foldLeft.x) / 2, y: (foldTop.y + foldLeft.y) / 2),
                        endPoint: mirrorCorner
                    ))

                    var hl = Path()
                    hl.move(to: foldTop)
                    hl.addLine(to: foldLeft)
                    ctx.stroke(hl, with: .color(.white.opacity(0.3)), lineWidth: 1)
                }
            }
            .overlay(
                paperContent
                    .overlay(paperTexture)
                    .overlay(paperEdgeShadow)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    .mask(
                        Canvas { ctx, size in
                            let sw = size.width, sh = size.height
                            let d = cornerPeel * min(sw, sh) * 0.65
                            var mask = Path()
                            mask.move(to: .zero)
                            mask.addLine(to: CGPoint(x: sw, y: 0))
                            if d > 1 {
                                mask.addLine(to: CGPoint(x: sw, y: sh - d))
                                mask.addLine(to: CGPoint(x: sw - d, y: sh))
                            } else {
                                mask.addLine(to: CGPoint(x: sw, y: sh))
                            }
                            mask.addLine(to: CGPoint(x: 0, y: sh))
                            mask.closeSubpath()
                            ctx.fill(mask, with: .color(.white))
                        }
                    )
            )
        }
        .aspectRatio(8.5 / 8, contentMode: .fit)
        .overlay(
            GeometryReader { geo in
                Color.clear.onAppear { paperSize = geo.size }
            }
        )
        // Paper press shader
        .colorEffect(
            ShaderLibrary.paperPress(
                .float2(paperSize.width, paperSize.height),
                .float2(rippleTouchPoint.x, rippleTouchPoint.y),
                .float(rippleTime),
                .float(rippleIntensity)
            )
        )
        // Burn effect
        .colorEffect(
            ShaderLibrary.paperBurnEffect(
                .float2(paperSize.width, paperSize.height),
                .float2(burnTouchPoint.x, burnTouchPoint.y),
                .float(burnProgress),
                .float(burnTime)
            )
        )
        // Micro animations: squash-stretch on tap
        .scaleEffect(x: tapStretch, y: tapSquash)
        // Breathing
        .scaleEffect(breathScale)
        // 3D tilt from gyroscope + drag
        .rotation3DEffect(.degrees(motion.pitch * 3 + dragTiltX + foldWobble), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
        .rotation3DEffect(.degrees(motion.roll * 3 + dragTiltY + foldWobble * 0.7), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .scaleEffect(liftScale)
        // Entrance
        .offset(y: entranceOffset)
        .opacity(entranceOpacity)
        // Shadow
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.12), radius: shadowSize, y: shadowSize * 0.5)
        .shadow(color: .black.opacity(0.06), radius: shadowSize * 3, y: shadowSize)
        // Tap → squash-stretch + press shader
        .onTapGesture { location in
            tapPaper(at: location)
        }
        // Drag → peel from corner OR tilt from anywhere else
        .gesture(combinedDragGesture)
        // Long press → lift
        .gesture(liftGesture)
        // Haptics
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: isLifted)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.3), trigger: cornerPeel > 0.2)
    }

    // MARK: - Tap → Squash + Press

    private func tapPaper(at point: CGPoint) {
        // Squash-stretch (Disney principle #1)
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            tapSquash = 0.97
            tapStretch = 1.02
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                tapSquash = 1.0
                tapStretch = 1.0
            }
        }

        // Press shader
        rippleTouchPoint = point
        rippleTime = 0
        rippleIntensity = 1.0
        rippleTimer?.invalidate()
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            rippleTime += 1.0 / 60.0
            rippleIntensity = max(0, 1.0 - rippleTime / 1.0)
            if rippleIntensity <= 0 { timer.invalidate(); rippleTimer = nil }
        }
    }

    // MARK: - Combined Drag (peel from corner, tilt from elsewhere)

    @State private var dragMode: DragMode = .none
    enum DragMode { case none, peel, tilt }

    private var combinedDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                // Decide mode on first move
                if dragMode == .none {
                    let sx = value.startLocation.x / max(paperSize.width, 1)
                    let sy = value.startLocation.y / max(paperSize.height, 1)
                    dragMode = (sx > 0.55 && sy > 0.55) ? .peel : .tilt
                }

                if dragMode == .peel {
                    let dx = value.startLocation.x - value.location.x
                    let dy = value.startLocation.y - value.location.y
                    let dist = sqrt(dx * dx + dy * dy)
                    withAnimation(.interactiveSpring(response: 0.12, dampingFraction: 0.8)) {
                        cornerPeel = min(dist / 250, 0.8)
                        shadowSize = 8 + cornerPeel * 12
                    }
                } else {
                    let tx = value.translation.width
                    let ty = value.translation.height
                    withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.7)) {
                        dragTiltY = tx * 0.06
                        dragTiltX = -ty * 0.06
                    }
                }
            }
            .onEnded { _ in
                if dragMode == .peel {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        cornerPeel = 0
                        shadowSize = 8
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        dragTiltX = 0
                        dragTiltY = 0
                    }
                }
                dragMode = .none
            }
    }

    // MARK: - Paper Content

    private let lineHeight: CGFloat = 22
    private let lineCount = 18
    private let topMargin: CGFloat = 36
    private let leftMargin: CGFloat = 42

    private var paperContent: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.94),
                    Color(red: 0.97, green: 0.95, blue: 0.91),
                    Color(red: 0.95, green: 0.93, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ruled lines
            VStack(spacing: 0) {
                Spacer().frame(height: topMargin)
                ForEach(0..<lineCount, id: \.self) { _ in
                    Spacer().frame(height: lineHeight - 0.5)
                    Rectangle()
                        .fill(Color(red: 0.55, green: 0.68, blue: 0.82).opacity(0.22))
                        .frame(height: 0.5)
                }
                Spacer()
            }

            // Red margin
            Rectangle()
                .fill(Color(red: 0.82, green: 0.30, blue: 0.30).opacity(0.35))
                .frame(width: 1.5)
                .padding(.leading, leftMargin)

            // Header line
            VStack {
                Spacer().frame(height: topMargin)
                Rectangle()
                    .fill(Color(red: 0.45, green: 0.58, blue: 0.78).opacity(0.3))
                    .frame(height: 1)
                Spacer()
            }

            // Text — staggered reveal
            VStack(alignment: .leading, spacing: lineHeight) {
                ForEach(Array(paperLines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.custom("Georgia", size: 13.5))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.22).opacity(line.isEmpty ? 0 : 0.65))
                        .kerning(0.2)
                        .lineLimit(1)
                        .opacity(index < visibleLines ? 1 : 0)
                        .offset(y: index < visibleLines ? 0 : 8)
                }
            }
            .padding(.top, topMargin + 4)
            .padding(.leading, leftMargin + 12)
            .padding(.trailing, 20)

            // Hole punches
            VStack {
                Spacer().frame(height: 50)
                holePunch
                Spacer()
                holePunch
                Spacer()
                holePunch
                Spacer().frame(height: 50)
            }
            .padding(.leading, 14)
        }
    }

    private var holePunch: some View {
        Circle()
            .fill(Color(red: 0.18, green: 0.15, blue: 0.13))
            .frame(width: 8, height: 8)
            .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .overlay(
                Circle().fill(
                    RadialGradient(colors: [.clear, .black.opacity(0.15)],
                                   center: .center, startRadius: 1, endRadius: 4)
                )
            )
    }

    private let paperLines = [
        "Dear Reader,",
        "",
        "This paper was crafted with",
        "SwiftUI and Metal shaders.",
        "",
        "Tilt your device to see the",
        "light shift across the surface.",
        "",
        "Drag the bottom corner to",
        "peel. Long press to lift the",
        "sheet off the desk.",
    ]

    // MARK: - Paper Texture Overlay

    private var paperTexture: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .colorEffect(
                    ShaderLibrary.paperTexture(
                        .float2(350, 500),
                        .float2(motion.roll, motion.pitch),
                        .float(0)
                    )
                )
                .blendMode(.multiply)
                .opacity(0.15)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RadialGradient(
                        colors: [Color(red: 0.85, green: 0.78, blue: 0.62).opacity(0.12), .clear],
                        center: .bottomTrailing, startRadius: 0, endRadius: 200
                    )
                    .frame(width: 200, height: 200)
                }
            }

            VStack {
                HStack {
                    RadialGradient(
                        colors: [Color(red: 0.88, green: 0.82, blue: 0.68).opacity(0.08), .clear],
                        center: .topLeading, startRadius: 0, endRadius: 150
                    )
                    .frame(width: 150, height: 150)
                    Spacer()
                }
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Edge Shadow

    private var paperEdgeShadow: some View {
        ZStack {
            VStack {
                LinearGradient(colors: [.black.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 8)
                Spacer()
            }
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.06)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
            }
            HStack {
                LinearGradient(colors: [.black.opacity(0.03), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 6)
                Spacer()
            }
            HStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.03)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 6)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private var liftGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onChanged { _ in
                // Anticipation — press down slightly before lifting
                withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                    liftScale = 0.96
                    shadowSize = 4
                }
            }
            .onEnded { _ in
                // Lift up with overshoot
                withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                    liftScale = 1.07
                    shadowSize = 35
                    isLifted = true
                }
                // Settle back with follow-through
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        liftScale = 1.0
                        shadowSize = 8
                        isLifted = false
                    }
                }
            }
    }
}

#Preview {
    PaperSheetView()
}
