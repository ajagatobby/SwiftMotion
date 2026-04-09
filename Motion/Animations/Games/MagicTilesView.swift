//
//  MagicTilesView.swift
//  Motion
//
//  Magic Tiles — tap the dark tiles as they scroll down.
//  Miss a tile or tap white space = game over.

import SwiftUI
import AVFoundation

// MARK: - Sound

final class TileSoundManager {
    static let shared = TileSoundManager()

    // 4 pitched notes — one per lane (C, E, G, B)
    private var notePlayers: [AVAudioPlayer] = []
    private var hitPlayer: AVAudioPlayer?

    private init() {
        // Use coin sound at different pitches for musical notes
        let rates: [Float] = [0.8, 1.0, 1.25, 1.5] // C E G B approximation
        for rate in rates {
            if let url = Bundle.main.url(forResource: "coin", withExtension: "wav", subdirectory: "Sounds") ??
                         Bundle.main.url(forResource: "coin", withExtension: "wav") {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.enableRate = true
                    p.rate = rate
                    p.volume = 0.4
                    p.prepareToPlay()
                    notePlayers.append(p)
                }
            }
        }

        if let url = Bundle.main.url(forResource: "hit", withExtension: "wav", subdirectory: "Sounds") ??
                     Bundle.main.url(forResource: "hit", withExtension: "wav") {
            hitPlayer = try? AVAudioPlayer(contentsOf: url)
            hitPlayer?.prepareToPlay()
        }
    }

    func playNote(lane: Int) {
        guard lane >= 0 && lane < notePlayers.count else { return }
        notePlayers[lane].currentTime = 0
        notePlayers[lane].play()
    }

    func playMiss() {
        hitPlayer?.currentTime = 0
        hitPlayer?.play()
    }
}

// MARK: - Haptics

final class TileHaptics {
    static let shared = TileHaptics()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let error = UINotificationFeedbackGenerator()

    private init() { light.prepare(); heavy.prepare() }

    func tap() { light.impactOccurred(intensity: 0.6) }
    func miss() { error.notificationOccurred(.error) }
    func combo() { heavy.impactOccurred(intensity: 0.8) }
}

// MARK: - Models

struct GameTile: Identifiable {
    let id = UUID()
    let lane: Int       // 0-3
    var y: CGFloat       // top edge position (scrolls down)
    let height: CGFloat  // tile height
    var tapped: Bool = false
    var missed: Bool = false
    let isLong: Bool          // long tile — must hold
    var holdProgress: CGFloat = 0  // 0→1 as player holds
    var isHolding: Bool = false    // currently being held
}

struct TapEffect {
    var x: CGFloat
    var y: CGFloat
    var time: CGFloat   // 0 = just tapped, grows
    var lane: Int
}

// MARK: - Engine

@Observable
final class MagicTilesEngine {
    enum State { case ready, playing, gameOver }

    var state: State = .ready
    var score: Int = 0
    var highScore: Int = 0
    var combo: Int = 0
    var maxCombo: Int = 0
    var tiles: [GameTile] = []
    var tapEffects: [TapEffect] = []
    var holdingLane: Int = -1  // which lane is currently held (-1 = none)
    var gameTime: Double = 0
    var speed: CGFloat = 250       // pixels per second
    var screenWidth: CGFloat = 0
    var screenHeight: CGFloat = 0

    private var lastDate: Date?
    private var spawnY: CGFloat = 0  // y position of next tile to spawn (above screen)

    var laneWidth: CGFloat { screenWidth / 4 }
    var tileHeight: CGFloat { screenHeight / 5 }

    func setSize(_ w: CGFloat, _ h: CGFloat) {
        screenWidth = w; screenHeight = h
    }

    func startGame() {
        state = .playing
        score = 0; combo = 0; maxCombo = 0
        speed = 250; gameTime = 0; lastDate = nil
        tiles.removeAll(); tapEffects.removeAll()
        holdingLane = -1
        spawnY = -tileHeight
        // Pre-spawn tiles filling the screen
        for i in 0..<6 {
            let lane = Int.random(in: 0...3)
            tiles.append(GameTile(
                lane: lane,
                y: -CGFloat(i) * tileHeight - tileHeight,
                height: tileHeight,
                isLong: false
            ))
        }
    }

    func update(date: Date) {
        // Tap effects always update
        for i in tapEffects.indices {
            tapEffects[i].time += 1.0 / 60.0
        }
        tapEffects.removeAll { $0.time > 0.5 }

        guard state == .playing else { return }
        guard let last = lastDate else { lastDate = date; return }
        let dt = min(date.timeIntervalSince(last), 1.0 / 30.0)
        lastDate = date
        guard dt > 0 else { return }
        gameTime += dt

        // Speed ramp
        speed = min(250 + CGFloat(gameTime) * 5, 800)

        // Move tiles down
        for i in tiles.indices {
            tiles[i].y += speed * CGFloat(dt)

            // Update long tile hold progress
            if tiles[i].isLong && tiles[i].isHolding && !tiles[i].tapped {
                tiles[i].holdProgress += CGFloat(dt) / (tiles[i].height / speed)
                if tiles[i].holdProgress >= 1.0 {
                    // Completed long tile!
                    tiles[i].tapped = true
                    tiles[i].holdProgress = 1.0
                    combo += 1
                    if combo > maxCombo { maxCombo = combo }
                    score += 3 // long tiles worth more
                    TileSoundManager.shared.playNote(lane: tiles[i].lane)
                    TileHaptics.shared.combo()
                }
            }

            // Long tile released too early
            if tiles[i].isLong && !tiles[i].isHolding && tiles[i].holdProgress > 0 && tiles[i].holdProgress < 1.0 && !tiles[i].tapped {
                tiles[i].missed = true
                gameOver()
                return
            }
        }

        // Check for missed tiles (scrolled past bottom without being tapped)
        for i in tiles.indices {
            if !tiles[i].tapped && !tiles[i].missed && tiles[i].y > screenHeight {
                tiles[i].missed = true
                gameOver()
                return
            }
        }

        // Remove tiles that are well past the screen
        tiles.removeAll { $0.y > screenHeight + 100 }

        // Spawn new tiles as needed
        let topTileY = tiles.min(by: { $0.y < $1.y })?.y ?? 0
        let spawnThreshold = -tileHeight
        if topTileY > spawnThreshold {
            let lane = Int.random(in: 0...3)

            // 20% chance of long tile after 10 seconds
            let isLong = gameTime > 10 && Double.random(in: 0...1) < 0.2
            let h = isLong ? tileHeight * CGFloat.random(in: 2.0...3.5) : tileHeight
            let spawnY = isLong ? topTileY - h : topTileY - tileHeight

            tiles.append(GameTile(
                lane: lane,
                y: spawnY,
                height: h,
                isLong: isLong
            ))

            // Double tile chance at high speed (not if long tile)
            if !isLong && speed > 500 && Double.random(in: 0...1) < 0.2 {
                var secondLane = Int.random(in: 0...3)
                while secondLane == lane { secondLane = Int.random(in: 0...3) }
                tiles.append(GameTile(
                    lane: secondLane,
                    y: topTileY - tileHeight,
                    height: tileHeight,
                    isLong: false
                ))
            }
        }
    }

    func tapAt(_ location: CGPoint) {
        guard state == .playing else { return }

        let tappedLane = Int(location.x / laneWidth)
        guard tappedLane >= 0 && tappedLane <= 3 else { return }

        // Find the lowest (closest to bottom) untapped tile in this lane
        var bestIndex: Int? = nil
        var bestY: CGFloat = -999

        for i in tiles.indices {
            if tiles[i].lane == tappedLane && !tiles[i].tapped && !tiles[i].missed {
                // Tile must be at least partially visible
                if tiles[i].y + tiles[i].height > 0 && tiles[i].y < screenHeight {
                    if tiles[i].y > bestY {
                        bestY = tiles[i].y
                        bestIndex = i
                    }
                }
            }
        }

        if let idx = bestIndex {
            if tiles[idx].isLong {
                // Long tile — start holding
                tiles[idx].isHolding = true
                holdingLane = tiles[idx].lane
                TileSoundManager.shared.playNote(lane: tiles[idx].lane)
                TileHaptics.shared.tap()
                let cx = CGFloat(tappedLane) * laneWidth + laneWidth / 2
                tapEffects.append(TapEffect(x: cx, y: location.y, time: 0, lane: tappedLane))
                return
            }

            // Regular tile — hit!
            tiles[idx].tapped = true
            combo += 1
            if combo > maxCombo { maxCombo = combo }

            // Score: base + combo bonus
            let points = 1 + (combo > 5 ? combo / 5 : 0)
            score += points

            // Effects
            let cx = CGFloat(tappedLane) * laneWidth + laneWidth / 2
            tapEffects.append(TapEffect(x: cx, y: location.y, time: 0, lane: tappedLane))

            TileSoundManager.shared.playNote(lane: tappedLane)
            TileHaptics.shared.tap()

            if combo > 0 && combo % 10 == 0 {
                TileHaptics.shared.combo()
            }
        } else {
            // Tapped white space — game over
            combo = 0
            TileSoundManager.shared.playMiss()
            TileHaptics.shared.miss()
            gameOver()
        }
    }

    func releaseHold() {
        guard holdingLane >= 0 else { return }
        // Release any held long tiles
        for i in tiles.indices {
            if tiles[i].isLong && tiles[i].isHolding && !tiles[i].tapped {
                tiles[i].isHolding = false
                // If not complete, this will be caught in update as early release
            }
        }
        holdingLane = -1
    }

    private func gameOver() {
        state = .gameOver
        holdingLane = -1
        if score > highScore { highScore = score }
    }
}

// MARK: - View

struct MagicTilesView: View {

    @State private var engine = MagicTilesEngine()
    @State private var gameOverScale: CGFloat = 0.5
    @State private var gameOverOpacity: CGFloat = 0

    let tileBlack = Color(red: 0.08, green: 0.08, blue: 0.12)
    let tileTapped = Color(red: 0.2, green: 0.5, blue: 1.0)
    let bgColor = Color(red: 0.96, green: 0.96, blue: 0.97)

    var body: some View {
        GeometryReader { geo in
            let _ = setupSize(geo.size)

            ZStack {
                bgColor.ignoresSafeArea()

                // Game area
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        drawGame(context: &context, size: size)
                    }
                    .drawingGroup()
                    .onChange(of: timeline.date) { _, d in engine.update(date: d) }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if engine.state == .playing {
                                engine.tapAt(value.startLocation)
                            }
                        }
                        .onEnded { _ in
                            engine.releaseHold()
                        }
                )

                // HUD
                if engine.state == .playing {
                    VStack {
                        HStack {
                            // Score
                            Text("\(engine.score)")
                                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 28))
                                .foregroundStyle(.black.opacity(0.7))
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.2), value: engine.score)

                            Spacer()

                            // Combo
                            if engine.combo >= 5 {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.orange)
                                    Text("x\(engine.combo)")
                                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.orange)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.orange.opacity(0.1)))
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                // Ready screen
                if engine.state == .ready {
                    readyScreen
                }

                // Game over
                if engine.state == .gameOver {
                    gameOverScreen
                        .onAppear { triggerGameOver() }
                }
            }
        }
    }

    private func setupSize(_ size: CGSize) {
        if engine.screenWidth == 0 {
            engine.setSize(size.width, size.height)
        }
    }

    // MARK: - Drawing

    private func drawGame(context: inout GraphicsContext, size: CGSize) {
        let e = engine
        let laneW = e.laneWidth

        // Background
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(bgColor))

        // Lane dividers
        for i in 1..<4 {
            let x = laneW * CGFloat(i)
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(Color.black.opacity(0.06)), lineWidth: 1)
        }

        // Tiles
        for tile in e.tiles {
            let x = CGFloat(tile.lane) * laneW
            let tileRect = CGRect(x: x + 2, y: tile.y + 2, width: laneW - 4, height: tile.height - 4)

            if tile.tapped {
                // Tapped — blue with fade
                let fadeAlpha = max(0, 1.0 - Double(tile.y - e.screenHeight * 0.3) / (e.screenHeight * 0.7))

                // 3D tile: shadow
                let shadowRect = CGRect(x: x + 4, y: tile.y + 5, width: laneW - 4, height: tile.height - 4)
                context.fill(Path(roundedRect: shadowRect, cornerRadius: 8),
                             with: .color(tileTapped.opacity(0.2 * fadeAlpha)))

                // Face
                context.fill(Path(roundedRect: tileRect, cornerRadius: 8),
                             with: .color(tileTapped.opacity(0.7 * fadeAlpha)))

                // Highlight
                let hlRect = CGRect(x: x + 6, y: tile.y + 4, width: laneW - 16, height: tile.height * 0.3)
                context.fill(Path(roundedRect: hlRect, cornerRadius: 6),
                             with: .color(Color.white.opacity(0.15 * fadeAlpha)))

            } else if tile.missed {
                // Missed — red flash
                context.fill(Path(roundedRect: tileRect, cornerRadius: 8),
                             with: .color(Color.red.opacity(0.8)))
            } else if tile.isLong {
                // Long tile — taller with hold progress indicator

                // Shadow
                let shadowRect = CGRect(x: x + 4, y: tile.y + 5, width: laneW - 4, height: tile.height - 4)
                context.fill(Path(roundedRect: shadowRect, cornerRadius: 10),
                             with: .color(Color.black.opacity(0.15)))

                // Tile body — gradient from dark to slightly lighter
                let longColor = tile.isHolding ? Color(red: 0.15, green: 0.25, blue: 0.5) : tileBlack
                context.fill(Path(roundedRect: tileRect, cornerRadius: 10),
                             with: .color(longColor))

                // Hold progress fill (from bottom up)
                if tile.holdProgress > 0 {
                    let fillH = tile.height * tile.holdProgress
                    let fillRect = CGRect(x: x + 3, y: tile.y + tile.height - fillH - 2, width: laneW - 6, height: fillH)
                    context.fill(Path(roundedRect: fillRect, cornerRadius: 8),
                                 with: .color(tileTapped.opacity(0.6)))
                }

                // Side bars indicating "hold"
                let barW: CGFloat = 3
                context.fill(Path(CGRect(x: x + 4, y: tile.y + 6, width: barW, height: tile.height - 12)),
                             with: .color(Color.white.opacity(tile.isHolding ? 0.2 : 0.06)))
                context.fill(Path(CGRect(x: x + laneW - 4 - barW, y: tile.y + 6, width: barW, height: tile.height - 12)),
                             with: .color(Color.white.opacity(tile.isHolding ? 0.2 : 0.06)))

                // Top highlight
                let hlRect = CGRect(x: x + 6, y: tile.y + 4, width: laneW - 16, height: 6)
                context.fill(Path(roundedRect: hlRect, cornerRadius: 3),
                             with: .color(Color.white.opacity(0.08)))

                // "HOLD" indicator dots
                let dotY = tile.y + tile.height / 2
                for d in 0..<3 {
                    let dotX = x + laneW / 2 - 12 + CGFloat(d) * 12
                    context.fill(Path(ellipseIn: CGRect(x: dotX - 2, y: dotY - 2, width: 4, height: 4)),
                                 with: .color(Color.white.opacity(tile.isHolding ? 0.4 : 0.12)))
                }

            } else {
                // Regular tile — dark with 3D depth

                // Shadow layer
                let shadowRect = CGRect(x: x + 4, y: tile.y + 5, width: laneW - 4, height: tile.height - 4)
                context.fill(Path(roundedRect: shadowRect, cornerRadius: 8),
                             with: .color(Color.black.opacity(0.15)))

                // Tile face
                context.fill(Path(roundedRect: tileRect, cornerRadius: 8),
                             with: .color(tileBlack))

                // Top highlight (3D lit edge)
                let hlRect = CGRect(x: x + 6, y: tile.y + 4, width: laneW - 16, height: tile.height * 0.15)
                context.fill(Path(roundedRect: hlRect, cornerRadius: 6),
                             with: .color(Color.white.opacity(0.08)))

                // Bottom dark edge
                let btRect = CGRect(x: x + 4, y: tile.y + tile.height - 8, width: laneW - 8, height: 4)
                context.fill(Path(roundedRect: btRect, cornerRadius: 2),
                             with: .color(Color.black.opacity(0.3)))
            }
        }

        // Tap ripple effects
        for effect in e.tapEffects {
            let radius = effect.time * 200
            let alpha = max(0, 1.0 - Double(effect.time) * 2.5)
            let color = tileTapped

            context.stroke(
                Path(ellipseIn: CGRect(x: effect.x - radius, y: effect.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(alpha * 0.4)),
                lineWidth: 2
            )
        }

        // Bottom guide line
        let guideY = size.height * 0.85
        context.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: guideY)); p.addLine(to: CGPoint(x: size.width, y: guideY)) },
            with: .color(Color.black.opacity(0.05)),
            lineWidth: 1
        )
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Magic")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 42))
                .foregroundStyle(.black)
            Text("Tiles")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 52))
                .foregroundStyle(tileTapped)

            Text("tap the dark tiles")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))

            if engine.highScore > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("\(engine.highScore)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))
                }
            }

            Spacer()

            Button {
                engine.startGame()
            } label: {
                Text("Play")
                    .font(.custom("BricolageGrotesque24pt-SemiBold", size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 160, height: 52)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.15))
                                .offset(y: 3)
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tileBlack)
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [.white.opacity(0.1), .clear],
                                                   startPoint: .top, endPoint: .center)
                                )
                                .padding(1)
                        }
                    )
            }
            .buttonStyle(TileButtonStyle())

            Spacer().frame(height: 50)
        }
    }

    // MARK: - Game Over

    private var gameOverScreen: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: engine.state)

            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.5))
                    .tracking(4)

                Text("\(engine.score)")
                    .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 80))
                    .foregroundStyle(.black)
                    .contentTransition(.numericText())

                if engine.maxCombo >= 5 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                        Text("Best combo: x\(engine.maxCombo)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                }

                Text("Best: \(engine.highScore)")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.3))

                Button {
                    gameOverScale = 0.5
                    gameOverOpacity = 0
                    engine.startGame()
                } label: {
                    Text("Retry")
                        .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 48)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(tileBlack.opacity(0.3))
                                    .offset(y: 3)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(tileBlack)
                            }
                        )
                }
                .buttonStyle(TileButtonStyle())
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            )
            .scaleEffect(gameOverScale)
            .opacity(gameOverOpacity)
        }
    }

    private func triggerGameOver() {
        gameOverScale = 0.5; gameOverOpacity = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            gameOverScale = 1.0
            gameOverOpacity = 1.0
        }
    }
}

// MARK: - Button Style

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    MagicTilesView()
}
