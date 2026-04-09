import SwiftUI
import AVFoundation

// MARK: - Sound Manager

final class SnakeSoundManager {
    static let shared = SnakeSoundManager()
    private var eatPlayer: AVAudioPlayer?
    private var hitPlayer: AVAudioPlayer?
    private init() {
        if let url = Bundle.main.url(forResource: "coin", withExtension: "wav") ??
                     Bundle.main.url(forResource: "coin", withExtension: "wav", subdirectory: "Sounds") {
            eatPlayer = try? AVAudioPlayer(contentsOf: url)
            eatPlayer?.prepareToPlay()
        }
        if let url = Bundle.main.url(forResource: "hit", withExtension: "wav") ??
                     Bundle.main.url(forResource: "hit", withExtension: "wav", subdirectory: "Sounds") {
            hitPlayer = try? AVAudioPlayer(contentsOf: url)
            hitPlayer?.prepareToPlay()
        }
    }
    func playEat() { eatPlayer?.currentTime = 0; eatPlayer?.play() }
    func playHit() { hitPlayer?.currentTime = 0; hitPlayer?.play() }
}

// MARK: - Game Engine

@Observable
final class SnakeEngine {
    enum GameState { case ready, playing, gameOver }
    enum Direction { case up, down, left, right }
    struct GridPoint: Equatable { var x: Int; var y: Int }

    enum FoodType { case normal, bonus, speed }

    struct Particle {
        var x, y, vx, vy: CGFloat
        var life: CGFloat  // 1→0
        var r, g, b: CGFloat
    }

    var state: GameState = .ready
    var score: Int = 0
    var highScore: Int = 0
    var combo: Int = 0
    var level: Int = 1

    var snake: [GridPoint] = []
    var food: GridPoint = GridPoint(x: 0, y: 0)
    var foodType: FoodType = .normal
    var foodPulse: Double = 0   // for animation
    var direction: Direction = .right
    var nextDirection: Direction = .right
    var directionQueue: [Direction] = []  // buffered inputs

    let gridSize: Int = 16
    var cellSize: CGFloat = 0
    var gameTime: Double = 0
    private var lastDate: Date?
    private var moveTimer: Double = 0
    var moveInterval: Double = 0.14
    private var baseInterval: Double = 0.14

    // Smooth movement interpolation (0→1 between grid steps)
    var moveProgress: CGFloat = 0
    var lastDirection: Direction = .right

    // Effects
    var particles: [Particle] = []
    var screenShake: CGFloat = 0
    var eatScale: CGFloat = 1.0     // head scale pulse on eat
    var bonusFoodTimer: Double = 0  // countdown for bonus food

    private var swipeProcessed = false
    private var comboTimer: Double = 0

    func configure(screenSize: CGFloat) {
        cellSize = floor(screenSize / CGFloat(gridSize))
    }

    var gridPixelSize: CGFloat { cellSize * CGFloat(gridSize) }
    var sizeReady: Bool { cellSize > 0 }

    func startGame() {
        let mid = gridSize / 2
        snake = [
            GridPoint(x: mid, y: mid),
            GridPoint(x: mid - 1, y: mid),
            GridPoint(x: mid - 2, y: mid)
        ]
        direction = .right
        nextDirection = .right
        lastDirection = .right
        directionQueue = []
        score = 0
        combo = 0
        level = 1
        moveTimer = 0
        baseInterval = 0.14
        moveInterval = 0.14
        gameTime = 0
        lastDate = nil
        moveProgress = 0
        particles = []
        screenShake = 0
        eatScale = 1.0
        bonusFoodTimer = 0
        comboTimer = 0
        spawnFood()
        state = .playing
    }

    func update(date: Date) {
        guard state == .playing else {
            // Decay particles even after game over
            decayEffects(dt: 1.0 / 60.0)
            return
        }
        guard let last = lastDate else { lastDate = date; return }
        let dt = min(date.timeIntervalSince(last), 1.0 / 30.0)
        lastDate = date
        guard dt > 0 else { return }
        gameTime += dt

        // Movement interpolation
        moveTimer += dt
        moveProgress = min(CGFloat(moveTimer / moveInterval), 1.0)

        if moveTimer >= moveInterval {
            moveTimer -= moveInterval
            moveProgress = 0
            step()
        }

        // Food pulse animation
        foodPulse = sin(gameTime * 4.0) * 0.15 + 1.0

        // Bonus food timer
        if bonusFoodTimer > 0 {
            bonusFoodTimer -= dt
            if bonusFoodTimer <= 0 {
                // Bonus expired, spawn normal food
                foodType = .normal
                spawnFood()
            }
        }

        // Combo decay
        if combo > 0 {
            comboTimer -= dt
            if comboTimer <= 0 { combo = 0 }
        }

        // Level up every 8 points
        let newLevel = min(score / 8 + 1, 10)
        if newLevel > level {
            level = newLevel
            baseInterval = max(0.055, 0.14 - Double(level - 1) * 0.009)
            moveInterval = baseInterval
        }

        // Effects
        decayEffects(dt: dt)
    }

    private func decayEffects(dt: Double) {
        // Particles
        for i in particles.indices {
            particles[i].x += particles[i].vx * CGFloat(dt)
            particles[i].y += particles[i].vy * CGFloat(dt)
            particles[i].vy += 80 * CGFloat(dt) // gravity
            particles[i].life -= CGFloat(dt) * 1.5
        }
        particles.removeAll { $0.life <= 0 }

        // Screen shake decay
        if screenShake > 0 { screenShake *= 0.85 }
        if screenShake < 0.5 { screenShake = 0 }

        // Eat scale decay
        if eatScale > 1.0 { eatScale += (1.0 - eatScale) * 0.15 }
        if abs(eatScale - 1.0) < 0.01 { eatScale = 1.0 }
    }

    private func step() {
        // Consume buffered direction
        if let queued = directionQueue.first {
            directionQueue.removeFirst()
            nextDirection = queued
        }

        lastDirection = direction
        direction = nextDirection

        guard let head = snake.first else { return }
        var newHead = head
        switch direction {
        case .up:    newHead.y -= 1
        case .down:  newHead.y += 1
        case .left:  newHead.x -= 1
        case .right: newHead.x += 1
        }

        // Wall collision
        if newHead.x < 0 || newHead.x >= gridSize || newHead.y < 0 || newHead.y >= gridSize {
            triggerDeath()
            return
        }

        // Self collision (skip tail tip since it moves away)
        let bodyCheck = snake.dropLast()
        if bodyCheck.contains(newHead) {
            triggerDeath()
            return
        }

        snake.insert(newHead, at: 0)

        if newHead == food {
            // Scoring
            var points = 1
            combo += 1
            comboTimer = 2.0 // 2 second combo window

            switch foodType {
            case .normal: points = 1 + (combo > 1 ? combo - 1 : 0)
            case .bonus:  points = 5 + combo
            case .speed:  points = 3
                // Temporary speed boost
                moveInterval = max(0.04, baseInterval * 0.6)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.moveInterval = self?.baseInterval ?? 0.1
                }
            }

            score += points
            if score > highScore { highScore = score }

            // Eat effect
            eatScale = 1.35
            spawnEatParticles(at: newHead)
            SnakeSoundManager.shared.playEat()

            // Decide next food
            spawnNextFood()
        } else {
            snake.removeLast()
        }
    }

    private func spawnNextFood() {
        let roll = Double.random(in: 0...1)
        if roll < 0.15 && level >= 3 {
            foodType = .bonus
            bonusFoodTimer = 6.0  // disappears after 6s
        } else if roll < 0.25 && level >= 5 {
            foodType = .speed
            bonusFoodTimer = 5.0
        } else {
            foodType = .normal
            bonusFoodTimer = 0
        }
        spawnFood()
    }

    private func spawnFood() {
        var candidates: [GridPoint] = []
        for x in 0..<gridSize { for y in 0..<gridSize {
            let p = GridPoint(x: x, y: y)
            if !snake.contains(p) { candidates.append(p) }
        }}
        if let pick = candidates.randomElement() { food = pick }
    }

    private func spawnEatParticles(at point: GridPoint) {
        let cx = CGFloat(point.x)
        let cy = CGFloat(point.y)
        for _ in 0..<8 {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 30...80)
            let r: CGFloat, g: CGFloat, b: CGFloat
            switch foodType {
            case .normal: r = 0; g = 1; b = 0.3
            case .bonus:  r = 1; g = 0.85; b = 0.1
            case .speed:  r = 0.3; g = 0.7; b = 1
            }
            particles.append(Particle(
                x: cx, y: cy,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                life: 1.0, r: r, g: g, b: b
            ))
        }
    }

    private func triggerDeath() {
        state = .gameOver
        screenShake = 8.0
        SnakeSoundManager.shared.playHit()

        // Death explosion particles from head
        if let head = snake.first {
            for _ in 0..<16 {
                let angle = CGFloat.random(in: 0...(.pi * 2))
                let speed = CGFloat.random(in: 40...120)
                particles.append(Particle(
                    x: CGFloat(head.x), y: CGFloat(head.y),
                    vx: cos(angle) * speed, vy: sin(angle) * speed,
                    life: 1.0, r: 1, g: 0.2, b: 0.3
                ))
            }
        }
    }

    // MARK: - Input

    func handleSwipeStart() { swipeProcessed = false }

    func handleSwipeChange(translation: CGSize) {
        guard !swipeProcessed else { return }
        let dx = translation.width, dy = translation.height
        guard max(abs(dx), abs(dy)) > 10 else { return }
        swipeProcessed = true
        let dir = resolveDirection(dx: dx, dy: dy)
        if let dir { queueDirection(dir) }
    }

    func setDirection(_ dir: Direction) {
        queueDirection(dir)
    }

    private func queueDirection(_ dir: Direction) {
        // Check against the last queued direction (or current)
        let ref = directionQueue.last ?? direction
        switch dir {
        case .up:    if ref != .down  { directionQueue.append(.up) }
        case .down:  if ref != .up    { directionQueue.append(.down) }
        case .left:  if ref != .right { directionQueue.append(.left) }
        case .right: if ref != .left  { directionQueue.append(.right) }
        }
        // Max 2 buffered inputs
        if directionQueue.count > 2 { directionQueue.removeFirst() }
    }

    private func resolveDirection(dx: CGFloat, dy: CGFloat) -> Direction? {
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }
}

// MARK: - Console Colors

private let consoleBody = Color(red: 0.12, green: 0.12, blue: 0.14)
private let consoleBodyLight = Color(red: 0.18, green: 0.18, blue: 0.20)
private let consoleBodyDark = Color(red: 0.06, green: 0.06, blue: 0.08)
private let screenBg = Color(red: 0.01, green: 0.02, blue: 0.04)
private let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.3)
private let neonPink = Color(red: 1.0, green: 0.2, blue: 0.4)

// MARK: - Console View

struct NeonSnakeView: View {
    @State private var engine = SnakeEngine()
    @State private var gameOverVisible = false
    @State private var gameOverTitleOffset: CGFloat = -40
    @State private var gameOverScoreScale: CGFloat = 0.3
    @State private var gameOverStatsOpacity: CGFloat = 0
    @State private var isNewHighScore = false

    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width - 40
            let _ = configureIfNeeded(screenW: screenW)

            ZStack {
                // Console body gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.13),
                        Color(red: 0.06, green: 0.06, blue: 0.08),
                        Color(red: 0.04, green: 0.04, blue: 0.05)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status bar above monitor
                    statusBar
                        .padding(.top, 56)
                        .padding(.bottom, 8)

                    // Game screen
                    gameScreenBezel(screenW: screenW)

                    Spacer()

                    // Controller — pinned to bottom
                    controllerSection
                        .padding(.bottom, 24)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { engine.handleSwipeChange(translation: $0.translation) }
                    .onEnded { _ in engine.handleSwipeStart() }
            )
        }
    }

    private func configureIfNeeded(screenW: CGFloat) {
        if !engine.sizeReady {
            engine.configure(screenSize: screenW - 20)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            // Level pill
            HStack(spacing: 4) {
                Circle()
                    .fill(neonGreen)
                    .frame(width: 5, height: 5)
                    .shadow(color: neonGreen.opacity(0.5), radius: 3)
                Text("LV \(engine.level)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(neonGreen.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(Capsule().strokeBorder(neonGreen.opacity(0.1), lineWidth: 0.5))
            )

            // Combo pill (when active)
            if engine.combo > 1 {
                let gold = Color(red: 1, green: 0.85, blue: 0.15)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(gold)
                    Text("x\(engine.combo)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(gold.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(gold.opacity(0.08))
                        .overlay(Capsule().strokeBorder(gold.opacity(0.15), lineWidth: 0.5))
                )
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Score
            Text("\(engine.score)")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 22))
                .foregroundStyle(neonGreen.opacity(0.8))
                .shadow(color: neonGreen.opacity(0.2), radius: 6)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: engine.score)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Game Screen Bezel

    private func gameScreenBezel(screenW: CGFloat) -> some View {
        ZStack {
            // Outer bezel shadow
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.03))
                .offset(y: 4)

            // Bezel body
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [consoleBodyLight, consoleBody, consoleBodyDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Bezel edge highlight
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.1), Color(white: 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Inner recess
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.02))
                .padding(8)

            // Screen
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(screenBg)

                if engine.state == .ready {
                    readyOverlay
                } else if engine.state == .gameOver {
                    ZStack {
                        gameCanvas
                        Color.black.opacity(gameOverVisible ? 0.8 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .animation(.easeOut(duration: 0.4), value: gameOverVisible)
                        gameOverOverlay
                    }
                    .onAppear { triggerGameOverAnimation() }
                } else {
                    gameCanvas
                        .onChange(of: engine.state) { _, newState in
                            if newState == .gameOver {
                                isNewHighScore = engine.score == engine.highScore && engine.score > 0
                            }
                        }
                }
            }
            .padding(10)

            // Screen glare
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.07), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 40)
                        .padding(.leading, 18)
                        .padding(.top, 16)
                    Spacer()
                }
                Spacer()
            }
            .allowsHitTesting(false)

            // Power LED + label
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.state == .playing ? neonGreen : neonGreen.opacity(0.2))
                        .frame(width: 5, height: 5)
                        .shadow(color: engine.state == .playing ? neonGreen.opacity(0.8) : .clear, radius: 5)
                    Text("PWR")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.25))
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: screenW, height: screenW * 1.0)
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }

    // MARK: - Game Canvas

    private var gameCanvas: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                drawGame(context: &context, size: size)
            }
            .onChange(of: timeline.date) { _, d in engine.update(date: d) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Ready Overlay

    private var readyOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo
            VStack(spacing: 4) {
                Text("NEON")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 36))
                    .foregroundStyle(neonGreen)
                Text("SNAKE")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 44))
                    .foregroundStyle(neonGreen)
            }
            .shadow(color: neonGreen.opacity(0.4), radius: 20)

            if engine.highScore > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.15))
                    Text("\(engine.highScore)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(neonGreen.opacity(0.5))
                }
            }

            Spacer()

            Text("▶ PRESS START")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(neonGreen.opacity(0.6))
                .tracking(2)

            Spacer().frame(height: 20)
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title — slides down
            Text("GAME OVER")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonPink)
                .tracking(5)
                .shadow(color: neonPink.opacity(0.6), radius: 12)
                .shadow(color: neonPink.opacity(0.3), radius: 24)
                .offset(y: gameOverTitleOffset)
                .opacity(gameOverVisible ? 1 : 0)

            Spacer().frame(height: 20)

            // Score — scales up with spring
            VStack(spacing: 6) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .tracking(3)
                    .opacity(gameOverStatsOpacity)

                Text("\(engine.score)")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 56))
                    .foregroundStyle(neonGreen)
                    .shadow(color: neonGreen.opacity(0.5), radius: 12)
                    .shadow(color: neonGreen.opacity(0.2), radius: 30)
                    .scaleEffect(gameOverScoreScale)
            }

            Spacer().frame(height: 16)

            // Stats row — fades in
            VStack(spacing: 10) {
                // New high score badge
                if isNewHighScore {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.15))
                        Text("NEW BEST!")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.15))
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.15))
                    }
                    .shadow(color: Color(red: 1, green: 0.85, blue: 0.15).opacity(0.4), radius: 8)
                    .opacity(gameOverStatsOpacity)
                }

                // Stats pills
                HStack(spacing: 12) {
                    statPill(icon: "trophy.fill", label: "\(engine.highScore)",
                             color: Color(red: 1, green: 0.85, blue: 0.15))
                    statPill(icon: "bolt.fill", label: "LV \(engine.level)",
                             color: neonGreen)
                    if engine.snake.count > 3 {
                        statPill(icon: "arrow.right", label: "\(engine.snake.count)",
                                 color: Color(red: 0.3, green: 0.7, blue: 1))
                    }
                }
                .opacity(gameOverStatsOpacity)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func statPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.8))
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().strokeBorder(color.opacity(0.15), lineWidth: 0.5))
        )
    }

    private func triggerGameOverAnimation() {
        // Reset
        gameOverVisible = false
        gameOverTitleOffset = -40
        gameOverScoreScale = 0.3
        gameOverStatsOpacity = 0

        // Sequence
        withAnimation(.easeOut(duration: 0.4)) {
            gameOverVisible = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
            gameOverTitleOffset = 0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.5)) {
            gameOverScoreScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
            gameOverStatsOpacity = 1.0
        }
    }

    private func resetGameOverAnimation() {
        gameOverVisible = false
        gameOverTitleOffset = -40
        gameOverScoreScale = 0.3
        gameOverStatsOpacity = 0
        isNewHighScore = false
    }

    // MARK: - Controller Section

    private var controllerSection: some View {
        HStack(alignment: .center) {
            Spacer().frame(width: 16)

            // D-Pad (left)
            consoleDPad

            Spacer()

            // Action button (right) — vertically centered with D-pad
            VStack(spacing: 10) {
                consoleActionButton(
                    label: engine.state == .ready ? "START" : "RETRY",
                    color: neonGreen
                ) {
                    resetGameOverAnimation()
                    engine.configure(screenSize: engine.gridPixelSize > 0 ? engine.gridPixelSize : 300)
                    engine.startGame()
                }

                Text("● \(engine.state == .playing ? "PLAYING" : "READY")")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.25))
            }

            Spacer().frame(width: 16)
        }
    }

    // MARK: - Console D-Pad

    private var consoleDPad: some View {
        let size: CGFloat = 52
        let gap: CGFloat = 3

        return ZStack {
            // Outer shadow (recessed look)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(white: 0.02))
                .frame(width: size * 3 + gap * 2 + 28, height: size * 3 + gap * 2 + 28)
                .shadow(color: .black.opacity(0.8), radius: 12, y: 6)

            // Base plate with inner shadow effect
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.1), Color(white: 0.05), Color(white: 0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                // Inner edge highlight (top-left light catch)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(white: 0.18), .clear, .clear, Color(white: 0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .frame(width: size * 3 + gap * 2 + 24, height: size * 3 + gap * 2 + 24)

            VStack(spacing: gap) {
                consoleDPadButton(icon: "chevron.up", w: size, h: size) { engine.setDirection(.up) }

                HStack(spacing: gap) {
                    consoleDPadButton(icon: "chevron.left", w: size, h: size) { engine.setDirection(.left) }

                    // Center knob — concave dish
                    ZStack {
                        // Outer ring
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.06), Color(white: 0.1)],
                                    center: .center, startRadius: 0, endRadius: size * 0.45
                                )
                            )
                            .frame(width: size, height: size)

                        // Inner dish
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.04), Color(white: 0.08)],
                                    center: .init(x: 0.4, y: 0.4), startRadius: 0, endRadius: size * 0.3
                                )
                            )
                            .frame(width: size * 0.55, height: size * 0.55)

                        // Ring highlight
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color(white: 0.2), Color(white: 0.06)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: size * 0.55, height: size * 0.55)
                    }

                    consoleDPadButton(icon: "chevron.right", w: size, h: size) { engine.setDirection(.right) }
                }

                consoleDPadButton(icon: "chevron.down", w: size, h: size) { engine.setDirection(.down) }
            }
        }
    }

    private func consoleDPadButton(icon: String, w: CGFloat, h: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                // Deep shadow (bottom)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.02))
                    .offset(y: 4)

                // Mid shadow
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.06))
                    .offset(y: 2)

                // Button face — main surface
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.22), Color(white: 0.14), Color(white: 0.10)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // Top bevel — bright edge
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.15), Color(white: 0.06), Color(white: 0.04)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )

                // Glossy top reflection
                VStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.3).opacity(0.5), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: w * 0.35)
                        .padding(.horizontal, 4)
                        .padding(.top, 3)
                    Spacer()
                }

                // Icon with glow
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(neonGreen)
                    .shadow(color: neonGreen.opacity(0.5), radius: 6)
                    .shadow(color: neonGreen.opacity(0.2), radius: 12)
            }
            .frame(width: w, height: h)
        }
        .buttonStyle(ConsoleButtonStyle())
    }

    // MARK: - Action Button

    private func consoleActionButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                // Shadow
                Capsule()
                    .fill(color.opacity(0.3))
                    .offset(y: 4)

                // Face
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // Gloss
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .padding(2)

                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black)
            }
            .frame(width: 100, height: 44)
            .shadow(color: color.opacity(0.4), radius: 10, y: 2)
        }
        .buttonStyle(ConsoleButtonStyle())
    }

    // MARK: - Drawing

    private func drawGame(context: inout GraphicsContext, size: CGSize) {
        let e = engine
        let cell = e.cellSize
        let gridPx = cell * CGFloat(e.gridSize)
        var originX = (size.width - gridPx) / 2
        var originY = (size.height - gridPx) / 2

        // Screen shake offset
        if e.screenShake > 0.5 {
            originX += CGFloat.random(in: -e.screenShake...e.screenShake)
            originY += CGFloat.random(in: -e.screenShake...e.screenShake)
        }

        // Background
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(screenBg))

        // Grid lines
        for i in 0...e.gridSize {
            let x = originX + CGFloat(i) * cell
            var pV = Path(); pV.move(to: CGPoint(x: x, y: originY)); pV.addLine(to: CGPoint(x: x, y: originY + gridPx))
            context.stroke(pV, with: .color(Color(white: 0.05)), lineWidth: 0.5)
            let y = originY + CGFloat(i) * cell
            var pH = Path(); pH.move(to: CGPoint(x: originX, y: y)); pH.addLine(to: CGPoint(x: originX + gridPx, y: y))
            context.stroke(pH, with: .color(Color(white: 0.05)), lineWidth: 0.5)
        }

        // Border
        context.stroke(Path(CGRect(x: originX, y: originY, width: gridPx, height: gridPx)),
                       with: .color(neonGreen.opacity(0.12)), lineWidth: 1)

        let pad: CGFloat = 1.5
        let progress = e.moveProgress

        // Food — different colors per type
        let foodColor: Color
        let foodGlowColor: Color
        switch e.foodType {
        case .normal: foodColor = neonPink; foodGlowColor = neonPink
        case .bonus:  foodColor = Color(red: 1.0, green: 0.85, blue: 0.1); foodGlowColor = Color(red: 1.0, green: 0.7, blue: 0.0)
        case .speed:  foodColor = Color(red: 0.3, green: 0.7, blue: 1.0); foodGlowColor = Color(red: 0.2, green: 0.5, blue: 1.0)
        }

        let fCX = originX + CGFloat(e.food.x) * cell + cell / 2
        let fCY = originY + CGFloat(e.food.y) * cell + cell / 2
        let pulse = CGFloat(e.foodPulse)

        // Food glow
        let glowR = cell * pulse
        context.fill(Path(ellipseIn: CGRect(x: fCX - glowR, y: fCY - glowR, width: glowR * 2, height: glowR * 2)),
                     with: .color(foodGlowColor.opacity(0.15)))

        // Food body
        let fR = (cell - pad * 2) / 2 * pulse
        context.fill(Path(ellipseIn: CGRect(x: fCX - fR, y: fCY - fR, width: fR * 2, height: fR * 2)),
                     with: .color(foodColor))

        // Bonus food: extra ring
        if e.foodType == .bonus {
            let ringR = fR + 3
            context.stroke(Path(ellipseIn: CGRect(x: fCX - ringR, y: fCY - ringR, width: ringR * 2, height: ringR * 2)),
                           with: .color(foodColor.opacity(0.5)), lineWidth: 1.5)
        }

        // Bonus timer indicator
        if e.bonusFoodTimer > 0 {
            let timerFrac = e.bonusFoodTimer / 6.0
            let arcR = fR + 6
            var arc = Path()
            arc.addArc(center: CGPoint(x: fCX, y: fCY), radius: arcR,
                       startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * timerFrac), clockwise: false)
            context.stroke(arc, with: .color(foodColor.opacity(0.3)), lineWidth: 2)
        }

        // Snake glow (all segments)
        for (i, seg) in e.snake.enumerated() {
            var cx = originX + CGFloat(seg.x) * cell + cell / 2
            var cy = originY + CGFloat(seg.y) * cell + cell / 2

            // Smooth interpolation for head
            if i == 0 {
                let dx: CGFloat, dy: CGFloat
                switch e.direction {
                case .up:    dx = 0; dy = -1
                case .down:  dx = 0; dy = 1
                case .left:  dx = -1; dy = 0
                case .right: dx = 1; dy = 0
                }
                cx += dx * cell * progress
                cy += dy * cell * progress
            }

            let gr = cell * (i == 0 ? 1.0 : 0.7)
            let ga = i == 0 ? 0.2 : max(0.03, 0.15 - Double(i) * 0.008)
            context.fill(Path(ellipseIn: CGRect(x: cx - gr, y: cy - gr, width: gr * 2, height: gr * 2)),
                         with: .color(neonGreen.opacity(ga)))
        }

        // Snake body
        for (i, seg) in e.snake.enumerated() {
            let isHead = i == 0
            var cx = originX + CGFloat(seg.x) * cell + cell / 2
            var cy = originY + CGFloat(seg.y) * cell + cell / 2

            // Smooth head interpolation
            if isHead {
                let dx: CGFloat, dy: CGFloat
                switch e.direction {
                case .up:    dx = 0; dy = -1
                case .down:  dx = 0; dy = 1
                case .left:  dx = -1; dy = 0
                case .right: dx = 1; dy = 0
                }
                cx += dx * cell * progress
                cy += dy * cell * progress
            }

            let p = isHead ? pad * 0.5 : pad
            let scale = isHead ? e.eatScale : 1.0
            let halfW = (cell - p * 2) / 2 * scale
            let r = CGRect(x: cx - halfW, y: cy - halfW, width: halfW * 2, height: halfW * 2)
            let cr: CGFloat = isHead ? cell * 0.3 : cell * 0.2

            // Body gradient: brighter near head, dimmer toward tail
            let brightness = max(0.4, 1.0 - Double(i) * 0.03)
            let segColor = isHead
                ? Color(red: 0.2, green: 1.0, blue: 0.5)
                : Color(red: 0, green: brightness, blue: 0.3 * brightness)

            context.fill(Path(roundedRect: r, cornerRadius: cr), with: .color(segColor))

            // Head eyes
            if isHead {
                let eyeOff: CGFloat = 3
                let eyeSize: CGFloat = 3
                var ex: CGFloat = 0, ey: CGFloat = 0
                switch e.direction {
                case .right: ex = eyeOff; ey = -eyeOff
                case .left:  ex = -eyeOff; ey = -eyeOff
                case .up:    ex = -eyeOff; ey = -eyeOff
                case .down:  ex = -eyeOff; ey = eyeOff
                }
                context.fill(Path(ellipseIn: CGRect(x: cx + ex - eyeSize/2, y: cy + ey - eyeSize/2,
                                                     width: eyeSize, height: eyeSize)),
                             with: .color(.white))
                // Second eye
                switch e.direction {
                case .right: ex = eyeOff; ey = eyeOff
                case .left:  ex = -eyeOff; ey = eyeOff
                case .up:    ex = eyeOff; ey = -eyeOff
                case .down:  ex = eyeOff; ey = eyeOff
                }
                context.fill(Path(ellipseIn: CGRect(x: cx + ex - eyeSize/2, y: cy + ey - eyeSize/2,
                                                     width: eyeSize, height: eyeSize)),
                             with: .color(.white))
            }
        }

        // Particles
        for p in e.particles {
            let px = originX + p.x * cell + cell / 2
            let py = originY + p.y * cell + cell / 2
            let s = 3.0 * p.life
            let color = Color(red: Double(p.r), green: Double(p.g), blue: Double(p.b))
            context.fill(Path(ellipseIn: CGRect(x: px - s, y: py - s, width: s * 2, height: s * 2)),
                         with: .color(color.opacity(Double(p.life))))
        }
    }
}

// MARK: - Console Button Style

private struct ConsoleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

#Preview {
    NeonSnakeView()
}
