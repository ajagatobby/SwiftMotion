//
//  DitherDashView.swift
//  Motion
//
//  Dither Dash — minimal endless runner in dithered B&W.

import SwiftUI
import AVFoundation

// MARK: - Sound Manager

final class DashSoundManager {
    static let shared = DashSoundManager()

    private var jumpPlayer: AVAudioPlayer?
    private var coinPlayer: AVAudioPlayer?
    private var hitPlayer: AVAudioPlayer?

    private init() {
        jumpPlayer = loadSound("jump", ext: "wav")
        coinPlayer = loadSound("coin", ext: "wav")
        hitPlayer = loadSound("hit", ext: "wav")

        // Pre-warm
        jumpPlayer?.prepareToPlay()
        coinPlayer?.prepareToPlay()
        hitPlayer?.prepareToPlay()
    }

    private func loadSound(_ name: String, ext: String) -> AVAudioPlayer? {
        // Try Sounds subdirectory first (filesystem sync puts files flat or in folder)
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") {
            return try? AVAudioPlayer(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return try? AVAudioPlayer(contentsOf: url)
        }
        return nil
    }

    func playJump() {
        jumpPlayer?.currentTime = 0
        jumpPlayer?.play()
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

// MARK: - Models

enum ObstacleType {
    case spike          // tall triangle — red — must jump
    case block          // wide low box — orange — must jump
    case doubleSpike    // two spikes close together — red
    case floatingBlock  // floating rectangle — purple — duck or time jump
    case movingSpike    // spike that bobs up/down — red
    case coin           // safe collectible — green
}

struct DashObstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    var yOffset: CGFloat
    let type: ObstacleType
    var isDangerous: Bool { type != .coin }
}

enum DashGameState {
    case ready, playing, gameOver
}

// MARK: - Engine

@Observable
final class DashEngine {
    var state: DashGameState = .ready
    var score: Int = 0
    var highScore: Int = 0
    var coins: Int = 0

    var playerY: CGFloat = 0
    private var playerVelocity: CGFloat = 0
    var isGrounded = true

    var obstacles: [DashObstacle] = []
    var groundOffset: CGFloat = 0
    var speed: CGFloat = 220.0
    var gameTime: Double = 0.0

    var touchPos: CGPoint = .zero
    var isTouching = false

    var screenWidth: CGFloat = 0
    var screenHeight: CGFloat = 0
    var groundY: CGFloat { screenHeight * 0.75 }
    let playerX: CGFloat = 70

    private var lastDate: Date?
    private var spawnTimer: Double = 2.5
    private var scoreTimer: Double = 0.0

    func setSize(_ size: CGSize) {
        screenWidth = size.width
        screenHeight = size.height
    }

    var sizeReady: Bool { screenWidth > 0 && screenHeight > 0 }

    func beginGame() {
        state = .playing
        score = 0
        coins = 0
        speed = 220.0
        playerY = 0
        playerVelocity = 0
        isGrounded = true
        obstacles.removeAll()
        gameTime = 0
        lastDate = nil
        spawnTimer = 2.5
        scoreTimer = 0
    }

    func jump() {
        guard state == .playing, isGrounded else { return }
        playerVelocity = -600.0
        isGrounded = false
        DashSoundManager.shared.playJump()
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

        // Player physics
        playerVelocity += 2100.0 * dt
        playerY += playerVelocity * dt
        if playerY >= 0 {
            playerY = 0
            playerVelocity = 0
            isGrounded = true
        }

        // Scrolling
        groundOffset -= speed * dt
        if groundOffset < -12 { groundOffset += 12 }

        // Score
        scoreTimer += dt
        if scoreTimer >= 0.1 {
            score += 1
            scoreTimer -= 0.1
        }

        // Speed ramp
        if gameTime > 4.0 {
            speed = min(220.0 + (gameTime - 4.0) * 6.0, 520.0)
        }

        // Spawn
        spawnTimer -= dt
        if spawnTimer <= 0 {
            spawnObstacle()
            let interval = max(1.4 - gameTime * 0.012, 0.55)
            spawnTimer = interval + Double.random(in: 0...0.5)
        }

        // Move & animate obstacles
        for i in obstacles.indices {
            obstacles[i].x -= speed * dt
            if obstacles[i].type == .movingSpike {
                obstacles[i].yOffset = sin(gameTime * 4.0 + Double(i)) * 20.0
            }
        }

        // Collect coins
        let playerRect = CGRect(x: playerX - 8, y: groundY + playerY - 32, width: 16, height: 28)
        for i in obstacles.indices where obstacles[i].type == .coin {
            let coinRect = CGRect(x: obstacles[i].x, y: groundY - obstacles[i].height + obstacles[i].yOffset,
                                  width: obstacles[i].width, height: obstacles[i].height)
            if playerRect.intersects(coinRect) {
                coins += 1
                score += 5
                obstacles[i].x = -999
                DashSoundManager.shared.playCoin()
            }
        }

        obstacles.removeAll { $0.x < -80 }

        // Collision
        if gameTime > 2.0 { checkCollision() }
    }

    private func spawnObstacle() {
        if let last = obstacles.last, last.x > screenWidth - 100 { return }

        let difficulty = min(gameTime / 30.0, 1.0) // 0→1 over 30 seconds
        let roll = Double.random(in: 0...1)

        if roll < 0.3 {
            // Spike
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 20, height: 48,
                                          color: Color(red: 0.9, green: 0.2, blue: 0.2), yOffset: 0, type: .spike))
        } else if roll < 0.5 {
            // Block
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 36, height: 24,
                                          color: Color(red: 0.95, green: 0.5, blue: 0.1), yOffset: 0, type: .block))
        } else if roll < 0.65 && difficulty > 0.2 {
            // Double spike
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 20, height: 48,
                                          color: Color(red: 0.9, green: 0.2, blue: 0.2), yOffset: 0, type: .spike))
            obstacles.append(DashObstacle(x: screenWidth + 65, width: 20, height: 40,
                                          color: Color(red: 0.85, green: 0.15, blue: 0.15), yOffset: 0, type: .doubleSpike))
        } else if roll < 0.75 && difficulty > 0.3 {
            // Floating block
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 50, height: 16,
                                          color: Color(red: 0.5, green: 0.3, blue: 0.8), yOffset: -60, type: .floatingBlock))
        } else if roll < 0.85 && difficulty > 0.5 {
            // Moving spike
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 20, height: 44,
                                          color: Color(red: 1.0, green: 0.3, blue: 0.3), yOffset: 0, type: .movingSpike))
        } else {
            // Coin
            obstacles.append(DashObstacle(x: screenWidth + 30, width: 18, height: 18,
                                          color: Color(red: 1.0, green: 0.75, blue: 0.1), yOffset: -45, type: .coin))
        }
    }

    private func checkCollision() {
        let playerRect = CGRect(x: playerX - 6, y: groundY + playerY - 30, width: 12, height: 26)
        for obs in obstacles where obs.isDangerous {
            let obsRect = CGRect(x: obs.x + 3, y: groundY - obs.height + obs.yOffset + 3,
                                 width: obs.width - 6, height: obs.height - 3)
            if playerRect.intersects(obsRect) {
                state = .gameOver
                if score > highScore { highScore = score }
                DashSoundManager.shared.playHit()
                return
            }
        }
    }
}

// MARK: - View

struct DitherDashView: View {

    @State private var engine = DashEngine()
    private let runnerImage = Image("runner")

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Color.clear.onAppear { engine.setSize(geo.size) }
                    .onChange(of: geo.size) { _, s in engine.setSize(s) }
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    drawGame(context: context, size: size, resolver: context)
                } symbols: {
                    runnerImage
                        .resizable()
                        .frame(width: 44, height: 44)
                        .tag("runner")
                }
                .onChange(of: timeline.date) { _, d in engine.update(date: d) }
            }
            .ignoresSafeArea()
            .colorEffect(
                ShaderLibrary.ditherDashEffect(
                    .float(2.5),
                    .float(engine.touchPos.x),
                    .float(engine.touchPos.y),
                    .float(engine.isTouching ? 1.0 : 0.0),
                    .float(85.0)
                )
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        engine.touchPos = v.location
                        engine.isTouching = true
                        if engine.state == .playing && engine.isGrounded { engine.jump() }
                    }
                    .onEnded { _ in engine.isTouching = false }
            )

            hudOverlay
        }
        .ignoresSafeArea()
    }

    // MARK: - Draw

    private func drawGame(context: GraphicsContext, size: CGSize, resolver: GraphicsContext) {
        let gY = engine.groundY

        // Flat sky
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(white: 0.96)))

        // Ground
        context.fill(Path(CGRect(x: 0, y: gY, width: size.width, height: size.height - gY)),
                     with: .color(Color(white: 0.88)))

        // Ground line
        context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: gY)); p.addLine(to: CGPoint(x: size.width, y: gY)) },
                       with: .color(Color(white: 0.7)), lineWidth: 1.5)

        // Ground dots
        var gx = engine.groundOffset
        while gx < size.width + 12 {
            context.fill(Path(ellipseIn: CGRect(x: gx, y: gY + 8, width: 3, height: 3)),
                         with: .color(Color(white: 0.78)))
            gx += 12
        }

        // Obstacles
        for obs in engine.obstacles {
            let baseY = gY - obs.height + obs.yOffset

            switch obs.type {
            case .spike, .doubleSpike, .movingSpike:
                var tri = Path()
                tri.move(to: CGPoint(x: obs.x + obs.width / 2, y: baseY))
                tri.addLine(to: CGPoint(x: obs.x + obs.width, y: gY))
                tri.addLine(to: CGPoint(x: obs.x, y: gY))
                tri.closeSubpath()
                context.fill(tri, with: .color(obs.color))

            case .block:
                context.fill(Path(CGRect(x: obs.x, y: baseY, width: obs.width, height: obs.height)),
                             with: .color(obs.color))

            case .floatingBlock:
                let rect = CGRect(x: obs.x, y: baseY, width: obs.width, height: obs.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(obs.color))

            case .coin:
                let cx = obs.x + obs.width / 2
                let cy = baseY + obs.height / 2
                let r = obs.width / 2
                // Outer ring
                context.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                             with: .color(Color(red: 1.0, green: 0.75, blue: 0.1)))
                // Inner circle
                context.fill(Path(ellipseIn: CGRect(x: cx - r + 3, y: cy - r + 3, width: r * 2 - 6, height: r * 2 - 6)),
                             with: .color(Color(red: 1.0, green: 0.85, blue: 0.3)))
                // Dollar sign
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy - 4))
                        p.addLine(to: CGPoint(x: cx, y: cy + 4))
                    },
                    with: .color(Color(red: 0.8, green: 0.55, blue: 0.0)),
                    lineWidth: 1.5
                )
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: cx + 2, y: cy - 2))
                        p.addQuadCurve(to: CGPoint(x: cx - 2, y: cy),
                                       control: CGPoint(x: cx - 3, y: cy - 3))
                        p.addQuadCurve(to: CGPoint(x: cx + 2, y: cy + 2),
                                       control: CGPoint(x: cx + 3, y: cy + 3))
                    },
                    with: .color(Color(red: 0.8, green: 0.55, blue: 0.0)),
                    lineWidth: 1.2
                )
            }
        }

        // Player — sprite character
        let px = engine.playerX
        let feetY = gY + engine.playerY
        let isJumping = engine.playerY < -2
        let spriteSize: CGFloat = 44

        // Shadow
        if !isJumping {
            context.fill(Path(ellipseIn: CGRect(x: px - 12, y: feetY - 2, width: 24, height: 5)),
                         with: .color(Color(white: 0.72)))
        }

        // Draw sprite
        if let resolved = resolver.resolveSymbol(id: "runner") {
            let tilt: CGFloat = isJumping ? -0.15 : 0
            var spriteCtx = context
            let spriteX = px - spriteSize / 2
            let spriteY = feetY - spriteSize
            spriteCtx.translateBy(x: spriteX + spriteSize / 2, y: spriteY + spriteSize / 2)
            spriteCtx.rotate(by: .radians(tilt))
            spriteCtx.draw(resolved, at: .zero)
        }
    }

    // MARK: - HUD

    private var hudOverlay: some View {
        ZStack {
            // Score during play
            if engine.state == .playing {
                VStack {
                    HStack {
                        Text("\(engine.score)")
                            .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 28))
                            .foregroundStyle(.black.opacity(0.7))

                        Spacer()

                        if engine.coins > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.1)).frame(width: 10, height: 10)
                                Text("\(engine.coins)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    Spacer()
                }
            }

            // Start screen
            if engine.state == .ready {
                VStack(spacing: 24) {
                    Text("Dither\nDash")
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 52))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-8)

                    Text("tap to jump · drag to see color")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.3))

                    Button {
                        engine.beginGame()
                    } label: {
                        Text("Play")
                            .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
                            .foregroundStyle(.white)
                            .frame(width: 140, height: 48)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black))
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

                    if engine.coins > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.1)).frame(width: 8, height: 8)
                            Text("\(engine.coins) coins")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.35))
                        }
                    }

                    Button {
                        engine.beginGame()
                    } label: {
                        Text("Retry")
                            .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
                            .foregroundStyle(.white)
                            .frame(width: 140, height: 48)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black))
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.92))
                )
            }
        }
        .allowsHitTesting(engine.state != .playing)
    }
}

#Preview {
    DitherDashView()
}
