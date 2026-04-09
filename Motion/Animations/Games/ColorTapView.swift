//
//  ColorTapView.swift
//  Motion
//
//  Color Tap — tap falling circles that match the target color.

import SwiftUI
import AVFoundation

// MARK: - Sound Manager

final class ColorTapSoundManager {
    static let shared = ColorTapSoundManager()

    private var coinPlayer: AVAudioPlayer?
    private var hitPlayer: AVAudioPlayer?

    private init() {
        coinPlayer = loadSound("coin", ext: "wav")
        hitPlayer = loadSound("hit", ext: "wav")

        coinPlayer?.prepareToPlay()
        hitPlayer?.prepareToPlay()
    }

    private func loadSound(_ name: String, ext: String) -> AVAudioPlayer? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") {
            return try? AVAudioPlayer(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return try? AVAudioPlayer(contentsOf: url)
        }
        return nil
    }

    func playCoin() {
        coinPlayer?.currentTime = 0
        coinPlayer?.play()
    }

    func playHit() {
        hitPlayer?.currentTime = 0
        hitPlayer?.play()
    }
}

// MARK: - Engine

@Observable
final class ColorTapEngine {

    enum GameState {
        case ready, playing, gameOver
    }

    enum GameColor: CaseIterable {
        case red, blue, green, yellow, purple

        var color: Color {
            switch self {
            case .red:    return Color(red: 0.9, green: 0.25, blue: 0.2)
            case .blue:   return Color(red: 0.2, green: 0.4, blue: 0.9)
            case .green:  return Color(red: 0.2, green: 0.75, blue: 0.3)
            case .yellow: return Color(red: 0.95, green: 0.8, blue: 0.1)
            case .purple: return Color(red: 0.6, green: 0.3, blue: 0.85)
            }
        }

        var name: String {
            switch self {
            case .red:    return "Red"
            case .blue:   return "Blue"
            case .green:  return "Green"
            case .yellow: return "Yellow"
            case .purple: return "Purple"
            }
        }
    }

    struct FallingCircle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let radius: CGFloat
        let gameColor: GameColor
        var popped: Bool = false
        var popScale: CGFloat = 1.0
        var popTimer: Double = 0
    }

    var state: GameState = .ready
    var score: Int = 0
    var highScore: Int = 0
    var lives: Int = 3
    var circles: [FallingCircle] = []
    var targetColor: GameColor = .red
    var speed: CGFloat = 150.0
    var screenWidth: CGFloat = 0
    var screenHeight: CGFloat = 0

    var shakeAmount: CGFloat = 0
    private var shakeTimer: Double = 0

    private var lastDate: Date?
    private var spawnTimer: Double = 0
    private var gameTime: Double = 0
    private var lastTargetChangeScore: Int = 0

    func setSize(_ size: CGSize) {
        screenWidth = size.width
        screenHeight = size.height
    }

    var sizeReady: Bool { screenWidth > 0 && screenHeight > 0 }

    func beginGame() {
        state = .playing
        score = 0
        lives = 3
        circles.removeAll()
        targetColor = GameColor.allCases.randomElement() ?? .red
        speed = 150.0
        lastDate = nil
        spawnTimer = 0.8
        gameTime = 0
        shakeAmount = 0
        shakeTimer = 0
        lastTargetChangeScore = 0
    }

    func update(date: Date) {
        guard state == .playing, sizeReady else { return }

        guard let last = lastDate else {
            lastDate = date
            return
        }

        let dt = min(date.timeIntervalSince(last), 1.0 / 30.0)
        guard dt > 0 else { return }
        lastDate = date
        gameTime += dt

        // Shake decay
        if shakeTimer > 0 {
            shakeTimer -= dt
            shakeAmount = shakeTimer > 0 ? CGFloat.random(in: -6...6) : 0
        } else {
            shakeAmount = 0
        }

        // Pop animations
        for i in circles.indices where circles[i].popped {
            circles[i].popTimer += dt
            let t = circles[i].popTimer
            circles[i].popScale = max(1.0 + CGFloat(t) * 4.0, 0)
        }
        circles.removeAll { $0.popped && $0.popTimer > 0.15 }

        // Speed ramp
        speed = min(150.0 + gameTime * 3.0, 400.0)

        // Change target color every 10 points
        let targetBracket = score / 10
        if targetBracket > lastTargetChangeScore / 10 {
            lastTargetChangeScore = score
            let others = GameColor.allCases.filter { $0 != targetColor }
            targetColor = others.randomElement() ?? .red
        }

        // Spawn circles
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnCircle()
            let interval = max(0.8 - gameTime * 0.008, 0.3)
            spawnTimer = interval + Double.random(in: 0...0.3)
        }

        // Move circles down
        for i in circles.indices where !circles[i].popped {
            circles[i].y += speed * dt
        }

        // Check for circles that fell off screen
        let fallen = circles.filter { !$0.popped && $0.y - $0.radius > screenHeight }
        for circle in fallen {
            if circle.gameColor == targetColor {
                loseLife()
            }
        }
        circles.removeAll { !$0.popped && $0.y - $0.radius > screenHeight }
    }

    func handleTap(at point: CGPoint) {
        guard state == .playing else { return }

        // Find closest circle within tap range
        var bestIndex: Int? = nil
        var bestDist: CGFloat = .greatestFiniteMagnitude

        for i in circles.indices where !circles[i].popped {
            let dx = circles[i].x - point.x
            let dy = circles[i].y - point.y
            let dist = sqrt(dx * dx + dy * dy)
            let tapRadius = circles[i].radius + 10 // generous tap area
            if dist < tapRadius && dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        guard let idx = bestIndex else { return }

        let circle = circles[idx]

        if circle.gameColor == targetColor {
            // Correct tap
            score += 1
            circles[idx].popped = true
            circles[idx].popTimer = 0
            ColorTapSoundManager.shared.playCoin()
        } else {
            // Wrong color
            circles.remove(at: idx)
            loseLife()
            ColorTapSoundManager.shared.playHit()
        }
    }

    private func loseLife() {
        lives -= 1
        shakeTimer = 0.3
        if lives <= 0 {
            state = .gameOver
            if score > highScore { highScore = score }
            ColorTapSoundManager.shared.playHit()
        }
    }

    private func spawnCircle() {
        let radius: CGFloat = 20
        let padding: CGFloat = radius + 10
        let x = CGFloat.random(in: padding...(screenWidth - padding))

        // Bias: ~40% chance to spawn target color so there are enough to tap
        let gameColor: GameColor
        if Double.random(in: 0...1) < 0.4 {
            gameColor = targetColor
        } else {
            gameColor = GameColor.allCases.randomElement() ?? .red
        }

        let circle = FallingCircle(
            x: x,
            y: -radius,
            radius: radius,
            gameColor: gameColor
        )
        circles.append(circle)
    }
}

// MARK: - View

struct ColorTapView: View {

    @State private var engine = ColorTapEngine()

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Color.clear.onAppear { engine.setSize(geo.size) }
                    .onChange(of: geo.size) { _, s in engine.setSize(s) }
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    drawGame(context: context, size: size)
                }
                .onChange(of: timeline.date) { _, d in engine.update(date: d) }
            }
            .ignoresSafeArea()
            .offset(x: engine.shakeAmount)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if engine.state == .playing {
                            engine.handleTap(at: value.location)
                        }
                    }
            )

            hudOverlay
        }
        .ignoresSafeArea()
    }

    // MARK: - Draw

    private func drawGame(context: GraphicsContext, size: CGSize) {
        // Background
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(white: 0.96))
        )

        // Draw falling circles
        for circle in engine.circles {
            let r = circle.radius * (circle.popped ? circle.popScale : 1.0)
            let opacity = circle.popped ? max(1.0 - circle.popTimer * 6.0, 0) : 1.0
            let rect = CGRect(
                x: circle.x - r,
                y: circle.y - r,
                width: r * 2,
                height: r * 2
            )

            // Shadow
            if !circle.popped {
                let shadowRect = rect.offsetBy(dx: 2, dy: 3)
                var shadowCtx = context
                shadowCtx.opacity = 0.12
                shadowCtx.fill(Path(ellipseIn: shadowRect), with: .color(.black))
            }

            // Circle
            var circleCtx = context
            circleCtx.opacity = opacity
            circleCtx.fill(Path(ellipseIn: rect), with: .color(circle.gameColor.color))

            // Shine highlight
            if !circle.popped {
                let shineRect = CGRect(
                    x: circle.x - r * 0.35,
                    y: circle.y - r * 0.6,
                    width: r * 0.5,
                    height: r * 0.35
                )
                var shineCtx = context
                shineCtx.opacity = 0.3
                shineCtx.fill(Path(ellipseIn: shineRect), with: .color(.white))
            }
        }
    }

    // MARK: - HUD

    private var hudOverlay: some View {
        ZStack {
            // Playing HUD
            if engine.state == .playing {
                VStack {
                    HStack(alignment: .center) {
                        // Target color indicator
                        HStack(spacing: 8) {
                            Text("Tap:")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.5))

                            Circle()
                                .fill(engine.targetColor.color)
                                .frame(width: 28, height: 28)
                                .shadow(color: engine.targetColor.color.opacity(0.4), radius: 4, y: 2)
                        }

                        Spacer()

                        // Score
                        Text("\(engine.score)")
                            .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 28))
                            .foregroundStyle(.black.opacity(0.7))

                        Spacer()

                        // Lives
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < engine.lives ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(i < engine.lives ? .red : .gray.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Start screen
            if engine.state == .ready {
                VStack(spacing: 24) {
                    Text("Color\nTap")
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 52))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-8)

                    Text("tap matching colors")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.3))

                    Light3DButton(title: "Play") {
                        engine.beginGame()
                    }
                }
            }

            // Game over
            if engine.state == .gameOver {
                VStack(spacing: 12) {
                    Text("\(engine.score)")
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 48))
                        .foregroundStyle(.black)

                    Text("Best: \(engine.highScore)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.35))

                    Light3DButton(title: "Retry") {
                        engine.beginGame()
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(white: 0.85))
                            .offset(y: 4)
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.95))
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.black.opacity(0.04), lineWidth: 0.5)
                    }
                )
            }
        }
        .allowsHitTesting(engine.state != .playing)
    }
}

// MARK: - 3D Light Button

private struct Light3DButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct Light3DButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
                .foregroundStyle(.white)
                .frame(width: 140, height: 48)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 0.12))
                            .offset(y: 3)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.2), .black],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                            .padding(1)
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(Light3DButtonStyle())
    }
}

#Preview {
    ColorTapView()
}
