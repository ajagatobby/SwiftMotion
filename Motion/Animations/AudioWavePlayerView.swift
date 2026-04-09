
import SwiftUI
import AVFoundation

// MARK: - Elastic Warp Modifier

struct ElasticWarpModifier: ViewModifier, Animatable {
    var dragPoint: CGPoint
    var dragTranslation: CGSize
    var isDragging: Bool

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(dragTranslation.width, dragTranslation.height) }
        set {
            dragTranslation.width = newValue.first
            dragTranslation.height = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: SizePreferenceKey.self,
                        value: geo.size
                    )
                }
            )
            .modifier(WarpEffect(
                dragPoint: dragPoint,
                translation: dragTranslation,
                size: CGSize(width: 340, height: 56) // approximate, updated by preference
            ))
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Uses a perspective transform to create a pull/warp effect
/// The area near the drag point moves more, far areas move less
struct WarpEffect: GeometryEffect {
    var dragPoint: CGPoint
    var translation: CGSize
    var size: CGSize

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(translation.width, translation.height) }
        set {
            translation.width = newValue.first
            translation.height = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let tx = translation.width
        let ty = translation.height

        // If no translation, identity
        if abs(tx) < 0.01 && abs(ty) < 0.01 {
            return ProjectionTransform(.identity)
        }

        let w = max(size.width, 1)
        let h = max(size.height, 1)

        // Normalize drag point to 0...1
        let px = dragPoint.x / w
        let py = dragPoint.y / h

        // Create a perspective warp that pulls the drag point
        // This uses a subtle perspective transform to create a rubbery deformation
        var transform = CATransform3DIdentity

        // Add perspective
        transform.m34 = -1.0 / 800

        // Rotate slightly based on where you're pulling
        // Pull right side → rotate around Y axis, pull top → rotate around X axis
        let rotateY = tx * 0.003 * (px - 0.5).sign  // stronger at edges
        let rotateX = -ty * 0.004 * (py - 0.5).sign

        transform = CATransform3DRotate(transform, rotateY, 0, 1, 0)
        transform = CATransform3DRotate(transform, rotateX, 1, 0, 0)

        // Translate slightly toward the drag direction
        transform = CATransform3DTranslate(transform, tx * 0.3, ty * 0.3, 0)

        // Scale — stretch in drag direction
        let scaleX = 1.0 + abs(tx) / w * 0.15
        let scaleY = 1.0 + abs(ty) / h * 0.15
        transform = CATransform3DScale(transform, scaleX, scaleY, 1)

        // Translate back to anchor at center
        let anchorX = w / 2
        let anchorY = h / 2
        let preTranslate = CATransform3DMakeTranslation(-anchorX, -anchorY, 0)
        let postTranslate = CATransform3DMakeTranslation(anchorX, anchorY, 0)

        let final3D = CATransform3DConcat(CATransform3DConcat(preTranslate, transform), postTranslate)

        return ProjectionTransform(final3D)
    }
}

private extension CGFloat {
    var sign: CGFloat { self >= 0 ? 1 : -1 }
}

// MARK: - Audio Wave Engine

@Observable
final class AudioWaveEngine {
    var amplitudes: [CGFloat] = []
    var isPlaying = false
    var progress: CGFloat = 0
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    // Animation state
    var phase: CGFloat = 0
    var revealProgress: CGFloat = 0       // 0→1 entrance reveal
    var barHeights: [CGFloat] = []        // current animated heights (0...1)
    var barTargets: [CGFloat] = []        // target heights (0...1)
    var barVelocities: [CGFloat] = []     // spring velocities

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    let barCount = 35

    // Spring parameters (inspired by Telegram: mass 3, stiffness 1000, damping 500)
    private let springStiffness: CGFloat = 320
    private let springDamping: CGFloat = 18

    init() {
        amplitudes = Array(repeating: 0.15, count: barCount)
        barHeights = Array(repeating: 0, count: barCount)
        barTargets = Array(repeating: 0, count: barCount)
        barVelocities = Array(repeating: 0, count: barCount)
    }

    func loadAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let candidates = [("voice_message", "mp3"), ("bgmusic", "mp3")]
        for (name, ext) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") ??
                         Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.prepareToPlay()
                    duration = player?.duration ?? 0
                    extractWaveform(from: url)
                    return
                } catch { continue }
            }
        }
    }

    private func extractWaveform(from url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            let frameCount = UInt32(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return }
            try file.read(into: buffer)
            guard let data = buffer.floatChannelData?[0] else { return }

            let total = Int(buffer.frameLength)
            let perBucket = total / barCount
            var amps: [CGFloat] = []
            var peak: CGFloat = 0

            for i in 0..<barCount {
                let start = i * perBucket
                let end = min(start + perBucket, total)
                var sum: Float = 0
                for s in start..<end { sum += data[s] * data[s] }
                let rms = CGFloat(sqrt(sum / Float(end - start)))
                amps.append(rms)
                if rms > peak { peak = rms }
            }

            let norm = peak > 0.0001 ? 1.0 / peak : 1.0
            amplitudes = amps.map { max(0.08, min(1.0, $0 * norm)) }
            barHeights = Array(repeating: 0, count: barCount)
            barTargets = Array(repeating: 0, count: barCount)
            barVelocities = Array(repeating: 0, count: barCount)
        } catch {}
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        isPlaying = true
        player?.play()
        startLink()
    }

    func pause() {
        isPlaying = false
        player?.pause()
    }

    func seek(to p: CGFloat) {
        progress = max(0, min(1, p))
        currentTime = Double(progress) * duration
        player?.currentTime = currentTime
    }

    func stop() {
        isPlaying = false
        player?.stop()
        displayLink?.invalidate()
        displayLink = nil
    }

    func startLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Telegram-style easing: cubic-bezier(0.23, 1.0, 0.32, 1.0) approximation
    /// Fast start, smooth settle with slight overshoot feel
    private func telegramEase(_ t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))
        // Attempt to match cubic-bezier(0.23, 1.0, 0.32, 1.0)
        // This is an ease-out curve that reaches ~1.0 quickly then settles
        return 1.0 - pow(1.0 - t, 3.5)
    }

    @objc private func tick() {
        let dt: CGFloat = 1.0 / 60.0

        // Advance swirl phase
        phase += dt * (isPlaying ? 3.5 : 0.8)

        // Advance reveal (0.8s duration like Telegram)
        if revealProgress < 1.0 {
            revealProgress = min(1.0, revealProgress + dt / 0.8)
        }

        // Playback progress
        if isPlaying, let p = player {
            currentTime = p.currentTime
            progress = CGFloat(currentTime / duration)
            if progress >= 1.0 {
                progress = 1.0; isPlaying = false
                player?.stop(); player?.currentTime = 0
            }
        }

        // Compute target heights with swirl + reveal
        let revealEased = telegramEase(revealProgress)

        for i in 0..<barCount {
            let t = CGFloat(i) / CGFloat(barCount - 1)
            var amp = amplitudes[i]

            // Swirl modulation — smooth sine layers
            let w1 = sin(phase * 1.8 + t * .pi * 5) * 0.10
            let w2 = sin(phase * 2.8 + t * .pi * 8) * 0.06
            let w3 = cos(phase * 1.0 + t * .pi * 3) * 0.07
            let swirl = (w1 + w2 + w3) * (isPlaying ? 0.9 : 0.25)
            amp = max(0.06, min(1.0, amp + swirl))

            // Telegram-style cascading reveal: bars on left appear first
            let barRevealStart = t * 0.5  // stagger: first bar at 0%, last at 50%
            let barRevealT = max(0, (revealEased - barRevealStart) / (1.0 - barRevealStart))
            let barRevealEased = telegramEase(barRevealT)
            amp *= barRevealEased

            barTargets[i] = amp
        }

        // Spring-animate each bar toward its target
        for i in 0..<barCount {
            let displacement = barHeights[i] - barTargets[i]
            let springForce = -springStiffness * displacement
            let dampingForce = -springDamping * barVelocities[i]
            barVelocities[i] += (springForce + dampingForce) * dt
            barHeights[i] += barVelocities[i] * dt
            barHeights[i] = max(0, barHeights[i])
        }
    }

    func animateIn() {
        revealProgress = 0
        startLink()
    }

    func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Audio Wave Player View

struct AudioWavePlayerView: View {
    @State private var engine = AudioWaveEngine()

    // Elastic drag state
    @State private var dragPoint: CGPoint = .zero
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging = false
    @Namespace private var playPauseNamespace

    var bubbleColor: Color = Color(red: 0.92, green: 0.33, blue: 0.33)

    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 2.5
    private let waveHeight: CGFloat = 28
    private let minBarH: CGFloat = 4

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            VStack(spacing: 40) {

                bubble
                    .padding(.horizontal, 20)
            }
        }
        .onAppear {
            engine.loadAudio()
            engine.animateIn()
        }
        .onDisappear { engine.stop() }
    }

    private var bubble: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    engine.togglePlayback()
                }
            } label: {
                ZStack {
                    // Shared background circle that morphs between states
                    Circle()
                        .fill(.white.opacity(engine.isPlaying ? 0.2 : 0.0))
                        .matchedGeometryEffect(
                            id: "playPauseBg",
                            in: playPauseNamespace
                        )

                    if engine.isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .matchedGeometryEffect(
                                id: "playPauseIcon",
                                in: playPauseNamespace
                            )
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .matchedGeometryEffect(
                                id: "playPauseIcon",
                                in: playPauseNamespace
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Circle())
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: engine.isPlaying)

            waveform

            Text(engine.formatTime(engine.isPlaying ? engine.currentTime : engine.duration))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: engine.currentTime)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(bubbleColor))
        // Elastic warp — drag any part and it follows your finger
        .modifier(ElasticWarpModifier(
            dragPoint: dragPoint,
            dragTranslation: dragTranslation,
            isDragging: isDragging
        ))
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    isDragging = true
                    dragPoint = value.startLocation
                    // Rubber-band: diminishing pull the further you drag
                    let tx = value.translation.width
                    let ty = value.translation.height
                    let rubberX = tx * 0.5 / (1 + abs(tx) / 200)
                    let rubberY = ty * 0.5 / (1 + abs(ty) / 200)
                    dragTranslation = CGSize(width: rubberX, height: rubberY)
                }
                .onEnded { _ in
                    isDragging = false
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.4)) {
                        dragTranslation = .zero
                    }
                }
        )
    }

    private func barColor(at i: Int) -> Color {
        let t = CGFloat(i) / 34.0
        let nextT = CGFloat(i + 1) / 35.0
        let mix: CGFloat
        if t < engine.progress {
            mix = nextT > engine.progress
                ? (engine.progress - t) / (nextT - t)
                : 1.0
        } else {
            mix = 0.0
        }
        return Color.white.opacity(0.35 + 0.65 * mix)
    }

    private var waveform: some View {
        GeometryReader { geo in
            HStack(spacing: barSpacing) {
                ForEach(0..<35) { i in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(barColor(at: i))
                        .frame(
                            width: barWidth,
                            height: max(minBarH, engine.barHeights[i] * waveHeight)
                        )
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        engine.seek(to: v.location.x / geo.size.width)
                    }
            )
        }
        .frame(height: waveHeight)
    }
}

#Preview {
    AudioWavePlayerView()
}
