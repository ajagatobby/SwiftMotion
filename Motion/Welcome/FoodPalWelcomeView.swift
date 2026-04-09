//
//  FoodPalWelcomeView.swift
//  Motion
//
//  Sequential welcome screen for FoodPal — a calorie tracker app.
//  4 phases: intro splash → transition sweep → feature cards → CTA.

import SwiftUI
import Combine

// MARK: - Animation Phase

private enum WelcomePhase: Int, Comparable {
    case black = 0
    case introFadeIn
    case iconEntrance
    case brandScramble
    case transitionDrift
    case subtitleType
    case cardsStagger
    case ctaEntrance
    case settled

    static func < (lhs: WelcomePhase, rhs: WelcomePhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Floating Particle

private struct FloatingParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let size: CGFloat
    let startX: CGFloat
    let duration: Double
    let delay: Double
    let swayAmount: CGFloat
}

// MARK: - Main View

struct FoodPalWelcomeView: View {

    // ── phase state ──
    @State private var phase: WelcomePhase = .black
    @State private var shaderTime: Float = 0
    @State private var displayLink: AnyCancellable?

    // ── intro ──
    @State private var bgOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.01
    @State private var iconRotation: Double = -90
    @State private var iconOpacity: Double = 0
    @State private var iconBreathe = false
    @State private var iconGlowRadius: CGFloat = 20

    // ── particle burst ──
    @State private var burstParticles: [BurstDot] = []
    @State private var burstFired = false

    // ── brand scramble ──
    @State private var brandChars: [Character] = Array(repeating: " ", count: 7)
    private let brandTarget: [Character] = Array("FoodPal")
    private let scramblePool = Array("!@#$%^&*ABCXYZ0123456789")
    @State private var brandResolved = 0
    @State private var brandTimer: AnyCancellable?
    @State private var charBounce: [Bool] = Array(repeating: false, count: 7)

    // ── transition ──
    @State private var headerOffset: CGFloat = 0
    @State private var headerScale: CGFloat = 1.0
    @State private var shimmerActive = false

    // ── subtitle typewriter ──
    private let subtitleText = "Your smart calorie companion"
    @State private var subtitleVisible = 0
    @State private var cursorVisible = true
    @State private var subtitleTimer: AnyCancellable?
    @State private var cursorTimer: AnyCancellable?

    // ── feature cards ──
    @State private var card1In = false
    @State private var card2In = false
    @State private var card3In = false
    @State private var iconPulse = false

    // ── floating particles ──
    @State private var floatingParticlesVisible = false
    private let floatingParticles: [FloatingParticle] = {
        let emojis = ["🍎", "🥑", "🍋", "🥕", "🍇", "🥦", "🍊", "🫐", "🍌", "🥗"]
        return (0..<10).map { i in
            FloatingParticle(
                emoji: emojis[i % emojis.count],
                size: CGFloat.random(in: 32...52),
                startX: CGFloat.random(in: 0.05...0.95),
                duration: Double.random(in: 8...14),
                delay: Double.random(in: 0...6),
                swayAmount: CGFloat.random(in: 20...50)
            )
        }
    }()

    // ── CTA ──
    @State private var ctaIn = false
    @State private var ctaGlow = false

    // ── haptics ──
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // ── shader phase value (0‥1) ──
    private var shaderPhase: Float {
        min(1.0, Float(phase.rawValue) / Float(WelcomePhase.settled.rawValue))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            backgroundLayer

            // Floating food emoji particles
            floatingParticleLayer

            VStack(spacing: 0) {
                Spacer()

                // Logo group — icon + brand text
                ZStack {
                    logoGroup

                    // Particle burst overlay
                    burstLayer
                }

                Spacer().frame(height: 12)

                subtitleRow
                    .padding(.top, 8)

                Spacer().frame(height: 36)

                featureCardsStack

                Spacer()

                ctaButton
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            prepareHaptics()
            startSequence()
        }
        .onDisappear(perform: cleanup)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                Rectangle()
                    .colorEffect(
                        ShaderLibrary.foodPalBackground(
                            .float2(geo.size),
                            .float(Float(context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 3600))),
                            .float(shaderPhase)
                        )
                    )
            }
        }
        .ignoresSafeArea()
        .opacity(bgOpacity)
    }

    // MARK: - Floating Particles Layer

    private var floatingParticleLayer: some View {
        GeometryReader { geo in
            ForEach(floatingParticles) { particle in
                FloatingEmojiView(
                    particle: particle,
                    screenHeight: geo.size.height,
                    visible: floatingParticlesVisible
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Burst Layer

    private var burstLayer: some View {
        ZStack {
            ForEach(burstParticles) { dot in
                Circle()
                    .fill(dot.color)
                    .frame(width: dot.size, height: dot.size)
                    .offset(x: burstFired ? dot.endX : 0,
                            y: burstFired ? dot.endY : 0)
                    .opacity(burstFired ? 0 : 1)
                    .scaleEffect(burstFired ? 0.2 : 1.0)
            }
        }
        .animation(.easeOut(duration: 0.8), value: burstFired)
    }

    // MARK: - Logo Group

    private var logoGroup: some View {
        VStack(spacing: 16) {
            // Fork+knife icon
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .orange.opacity(0.5), radius: iconGlowRadius, y: 4)
                .scaleEffect(iconScale * (iconBreathe ? 1.05 : 1.0))
                .rotationEffect(.degrees(iconRotation))
                .opacity(iconOpacity)
                .animation(
                    iconBreathe
                        ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                        : .default,
                    value: iconBreathe
                )

            // Brand name — scramble decode with per-char bounce
            HStack(spacing: 3) {
                ForEach(Array(brandChars.enumerated()), id: \.offset) { idx, char in
                    Text(String(char))
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 48))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        .scaleEffect(charBounce[safe: idx] == true ? 1.15 : (idx < brandResolved ? 1.0 : 0.85))
                        .offset(y: charBounce[safe: idx] == true ? -8 : 0)
                        .opacity(idx < brandResolved ? 1.0 : 0.5)
                        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: charBounce[safe: idx])
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: brandResolved)
                }
            }
        }
        .offset(y: headerOffset)
        .scaleEffect(headerScale)
    }

    // MARK: - Subtitle

    private var subtitleRow: some View {
        HStack(spacing: 0) {
            Text(String(subtitleText.prefix(subtitleVisible)))
                .font(.custom("BricolageGrotesque24pt-Medium", size: 16))
                .foregroundStyle(.white.opacity(0.8))

            Text("|")
                .font(.custom("BricolageGrotesque24pt-Medium", size: 16))
                .foregroundStyle(.white.opacity(cursorVisible ? 0.8 : 0))
                .animation(.easeInOut(duration: 0.3), value: cursorVisible)
        }
        .opacity(phase >= .subtitleType ? 1 : 0)
        .offset(y: headerOffset * 0.6)
    }

    // MARK: - Feature Cards

    private var featureCardsStack: some View {
        VStack(spacing: 14) {
            featureCard(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Track Meals",
                subtitle: "Log food in seconds with smart search",
                isIn: card1In,
                microAnimation: .glow,
                slideFrom: .leading
            )
            featureCard(
                icon: "chart.bar.fill",
                iconColor: .green,
                title: "Smart Insights",
                subtitle: "See trends and patterns in your nutrition",
                isIn: card2In,
                microAnimation: .wiggle,
                slideFrom: .trailing
            )
            featureCard(
                icon: "target",
                iconColor: .red,
                title: "Hit Your Goals",
                subtitle: "Custom calorie and macro targets",
                isIn: card3In,
                microAnimation: .pop,
                slideFrom: .leading
            )
        }
    }

    private func featureCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isIn: Bool,
        microAnimation: CardMicro,
        slideFrom: HorizontalAlignment
    ) -> some View {
        let slideX: CGFloat = slideFrom == .leading ? -40 : 40

        return HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .modifier(CardIconAnimator(micro: microAnimation, active: iconPulse))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.custom("BricolageGrotesque24pt-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .colorEffect(
                        ShaderLibrary.shimmerEffect(
                            .float2(geo.size),
                            .float(shimmerActive ? shaderTime : 0),
                            .float(0.4),
                            .float(0.22)
                        )
                    )
            }
            .allowsHitTesting(false)
        )
        .offset(x: isIn ? 0 : slideX, y: isIn ? 0 : 50)
        .opacity(isIn ? 1 : 0)
        .rotation3DEffect(
            .degrees(isIn ? 0 : (slideFrom == .leading ? -8 : 8)),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(response: 0.65, dampingFraction: 0.7), value: isIn)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: {}) {
            ZStack {
                Text("Get Started")
                    .font(.custom("BricolageGrotesque24pt-Bold", size: 18))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.75, blue: 0.3),
                                Color(red: 1.0, green: 0.55, blue: 0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(
                        color: .orange.opacity(ctaGlow ? 0.65 : 0.2),
                        radius: ctaGlow ? 24 : 6,
                        y: 4
                    )
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .offset(y: ctaIn ? 0 : 80)
        .opacity(ctaIn ? 1 : 0)
        .scaleEffect(ctaIn ? 1.0 : 0.8)
        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: ctaIn)
        .animation(
            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
            value: ctaGlow
        )
    }

    // MARK: - Sequence Orchestration

    private func startSequence() {
        let start = Date()
        displayLink = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                shaderTime = Float(Date().timeIntervalSince(start))
            }

        cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in cursorVisible.toggle() }

        // ── Phase 1: fade in background
        schedule(0.2) {
            phase = .introFadeIn
            withAnimation(.easeIn(duration: 1.2)) { bgOpacity = 1.0 }
        }

        // ── Phase 2: icon entrance with haptic
        schedule(0.7) {
            phase = .iconEntrance
            iconOpacity = 1
            impactHeavy.impactOccurred()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
                iconScale = 1.0
                iconRotation = 0
            }
            // Glow pulse on landing
            withAnimation(.easeOut(duration: 0.4)) { iconGlowRadius = 35 }
            schedule(0.4) {
                withAnimation(.easeIn(duration: 0.5)) { iconGlowRadius = 20 }
            }
        }

        // ── Particle burst after icon lands
        schedule(1.0) {
            fireBurst()
        }

        // ── Icon starts breathing
        schedule(1.3) {
            iconBreathe = true
        }

        // ── Phase 3: brand scramble with per-char haptic
        schedule(1.2) {
            phase = .brandScramble
            startBrandScramble()
        }

        // ── Phase 4: drift up + shimmer + floating particles
        schedule(2.6) {
            phase = .transitionDrift
            shimmerActive = true
            floatingParticlesVisible = true
            impactLight.impactOccurred()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.72)) {
                headerOffset = -60
                headerScale = 0.85
            }
        }

        // ── Phase 5: subtitle typewriter
        schedule(3.2) {
            phase = .subtitleType
            startSubtitleTypewriter()
        }

        // ── Phase 6: cards stagger in with haptics
        schedule(4.2) {
            phase = .cardsStagger
            impactMedium.impactOccurred()
            card1In = true
        }
        schedule(4.55) {
            impactLight.impactOccurred()
            card2In = true
        }
        schedule(4.9) {
            impactLight.impactOccurred()
            card3In = true
        }
        schedule(5.3) {
            withAnimation(.easeInOut(duration: 1.0)) { iconPulse = true }
        }

        // ── Phase 7: CTA entrance with haptic
        schedule(6.0) {
            phase = .ctaEntrance
            impactMedium.impactOccurred()
            ctaIn = true
        }
        schedule(6.5) {
            notificationFeedback.notificationOccurred(.success)
            ctaGlow = true
        }

        // ── Phase 8: settled
        schedule(6.8) {
            phase = .settled
        }
    }

    // MARK: - Particle Burst

    private func fireBurst() {
        let colors: [Color] = [
            .orange, .yellow, .green, .red,
            Color(red: 1, green: 0.75, blue: 0.3)
        ]
        burstParticles = (0..<16).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...120)
            return BurstDot(
                endX: cos(angle) * distance,
                endY: sin(angle) * distance,
                size: CGFloat.random(in: 4...8),
                color: colors.randomElement()!
            )
        }
        impactLight.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            burstFired = true
        }
    }

    // MARK: - Brand Scramble

    private func startBrandScramble() {
        brandResolved = 0
        charBounce = Array(repeating: false, count: brandTarget.count)
        brandChars = brandTarget.map { _ in scramblePool.randomElement()! }
        var tickCount = 0
        let resolveEvery = 5

        brandTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                tickCount += 1

                if tickCount % resolveEvery == 0 && brandResolved < brandTarget.count {
                    let idx = brandResolved
                    brandResolved += 1
                    impactLight.impactOccurred()

                    // Per-character bounce
                    charBounce[idx] = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        charBounce[idx] = false
                    }
                }

                var next: [Character] = []
                for i in 0..<brandTarget.count {
                    if i < brandResolved {
                        next.append(brandTarget[i])
                    } else {
                        next.append(scramblePool.randomElement()!)
                    }
                }
                brandChars = next

                if brandResolved >= brandTarget.count {
                    brandTimer?.cancel()
                }
            }
    }

    // MARK: - Subtitle Typewriter

    private func startSubtitleTypewriter() {
        subtitleVisible = 0
        subtitleTimer = Timer.publish(every: 0.045, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if subtitleVisible < subtitleText.count {
                    subtitleVisible += 1
                } else {
                    subtitleTimer?.cancel()
                }
            }
    }

    // MARK: - Helpers

    private func schedule(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    private func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationFeedback.prepare()
    }

    private func cleanup() {
        displayLink?.cancel()
        brandTimer?.cancel()
        subtitleTimer?.cancel()
        cursorTimer?.cancel()
    }
}

// MARK: - Burst Dot

private struct BurstDot: Identifiable {
    let id = UUID()
    let endX: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let color: Color
}

// MARK: - Floating Emoji View

private struct FloatingEmojiView: View {
    let particle: FloatingParticle
    let screenHeight: CGFloat
    let visible: Bool

    @State private var animate = false

    var body: some View {
        Text(particle.emoji)
            .font(.system(size: particle.size))
            .offset(
                x: animate ? particle.swayAmount : -particle.swayAmount,
                y: animate ? -screenHeight - 60 : screenHeight + 60
            )
            .opacity(animate ? 0 : 0.35)
            .position(x: UIScreen.main.bounds.width * particle.startX, y: screenHeight)
            .animation(
                animate
                    ? .linear(duration: particle.duration).repeatForever(autoreverses: false)
                    : .default,
                value: animate
            )
            .onChange(of: visible) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + particle.delay) {
                        animate = true
                    }
                }
            }
    }
}

// MARK: - Card Micro-Animation Types

private enum CardMicro {
    case glow      // subtle glow pulse on the icon background
    case wiggle    // gentle horizontal wiggle
    case pop       // scale pop then settle
}

private struct CardIconAnimator: ViewModifier {
    let micro: CardMicro
    let active: Bool

    func body(content: Content) -> some View {
        switch micro {
        case .glow:
            content
                .shadow(color: .orange.opacity(active ? 0.5 : 0), radius: active ? 8 : 0)
                .animation(
                    active
                        ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                        : .default,
                    value: active
                )
        case .wiggle:
            content
                .rotationEffect(.degrees(active ? 3 : -3))
                .animation(
                    active
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: active
                )
        case .pop:
            content
                .scaleEffect(active ? 1.05 : 0.98)
                .animation(
                    active
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        : .default,
                    value: active
                )
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    FoodPalWelcomeView()
        .preferredColorScheme(.dark)
}
