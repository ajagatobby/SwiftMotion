//
//  MeditationWelcomeView.swift
//  Motion
//
//  Meditation app welcome screen with breathing circle,
//  floating star particles, and calming gradient.

import SwiftUI
import Combine

// MARK: - Star Particle

private struct StarParticle: Identifiable {
    let id = UUID()
    let angle: Double        // direction from center (radians)
    let speed: CGFloat       // how far it travels
    let maxSize: CGFloat     // size when closest to viewer
    let duration: Double     // loop duration
    let delay: Double        // stagger
}

// MARK: - Main View

struct MeditationWelcomeView: View {

    // ── animation state ──
    @State private var breathe = false
    @State private var logoIn = false
    @State private var titleIn = false
    @State private var subtitleIn = false
    @State private var starsVisible = false
    @State private var buttonIn = false
    @State private var gradientPhase = false
    @State private var ringRotation: Double = 0
    @State private var innerGlow = false
    @State private var blinking = false
    @State private var blinkTimer: Timer?

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    // ── star particles ──
    private let stars: [StarParticle] = (0..<35).map { _ in
        StarParticle(
            angle: Double.random(in: 0...(2 * .pi)),
            speed: CGFloat.random(in: 0.3...1.0),
            maxSize: CGFloat.random(in: 5...14),
            duration: Double.random(in: 3...7),
            delay: Double.random(in: 0...5)
        )
    }

    var body: some View {
        ZStack {
            // ── Background Gradient ──
            backgroundGradient

            // ── Floating Stars ──
            starField

            VStack(spacing: 0) {
                Spacer()

                // ── Breathing Circle ──
                breathingCircle
                    .padding(.bottom, 40)

                // ── Title ──
                VStack(spacing: 8) {
                    Text("Find your")
                        .font(.custom("BricolageGrotesque24pt-Regular", size: 18))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("Inner Peace")
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 42))
                        .foregroundStyle(.white)
                }
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 15)
                .blur(radius: titleIn ? 0 : 8)
                .animation(.easeOut(duration: 0.8), value: titleIn)

                // ── Subtitle ──
                Text("Breathe deeply. Let go.\nBe present in the moment.")
                    .font(.custom("BricolageGrotesque24pt-Regular", size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 16)
                    .opacity(subtitleIn ? 1 : 0)
                    .offset(y: subtitleIn ? 0 : 10)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: subtitleIn)

                Spacer()
                Spacer()

                // ── Breathing hint ──
                Text(breathe ? "Breathe out..." : "Breathe in...")
                    .font(.custom("BricolageGrotesque24pt-Medium", size: 13))
                    .foregroundStyle(.white.opacity(0.3))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.5), value: breathe)
                    .padding(.bottom, 20)

                // ── CTA Button — Duolingo 3D style ──
                Button(action: {}) {
                    Text("Begin Your Journey")
                        .font(.custom("BricolageGrotesque24pt-Bold", size: 17))
                        .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.25))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                // Bottom shadow layer — 3D depth
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 0.78, green: 0.78, blue: 0.82))
                                    .offset(y: 4)

                                // Main white surface
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white)

                                // Top highlight
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, Color(red: 0.94, green: 0.94, blue: 0.96)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(Duolingo3DButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
                .opacity(buttonIn ? 1 : 0)
                .offset(y: buttonIn ? 0 : 25)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: buttonIn)
            }
        }
        .safeAreaPadding(.bottom)
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
            startSequence()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.06, blue: 0.18),
                gradientPhase
                    ? Color(red: 0.12, green: 0.08, blue: 0.28)
                    : Color(red: 0.10, green: 0.12, blue: 0.22),
                gradientPhase
                    ? Color(red: 0.18, green: 0.10, blue: 0.30)
                    : Color(red: 0.14, green: 0.08, blue: 0.25),
                Color(red: 0.06, green: 0.04, blue: 0.14),
            ],
            startPoint: gradientPhase ? .topLeading : .top,
            endPoint: gradientPhase ? .bottomTrailing : .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: gradientPhase)
    }

    // MARK: - Star Field (warp / coming forward)

    private var starField: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let cx = geo.size.width / 2
                let cy = geo.size.height / 2
                let maxRadius = max(geo.size.width, geo.size.height) * 0.7

                Canvas { context, size in
                    guard starsVisible else { return }

                    for star in stars {
                        // Progress: 0 (center) → 1 (edge), loops continuously
                        let elapsed = now - star.delay
                        let progress = CGFloat(((elapsed / star.duration).truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0))

                        // Ease-in: accelerate as it comes toward you
                        let eased = progress * progress

                        // Position: from center outward along the angle
                        let dist = eased * maxRadius * star.speed
                        let x = cx + cos(star.angle) * dist
                        let y = cy + sin(star.angle) * dist

                        // Size: grows as it approaches (tiny at center, big at edge)
                        let size = star.maxSize * (0.3 + eased * 0.7)

                        // Opacity: fade in then out — peak around 0.6
                        let alpha = min(progress * 2.5, 1.0) * max(1.0 - (progress - 0.7) * 3.3, 0.3)

                        let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Breathing Circle

    private var breathingCircle: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.50, green: 0.40, blue: 0.80).opacity(breathe ? 0.3 : 0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: breathe ? 110 : 80
                    )
                )
                .frame(width: 220, height: 220)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)

            // Rotating ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.05),
                            .white.opacity(0.15),
                            Color(red: 0.60, green: 0.50, blue: 0.90).opacity(0.3),
                            .white.opacity(0.05),
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: breathe ? 140 : 110, height: breathe ? 140 : 110)
                .rotationEffect(.degrees(ringRotation))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: ringRotation)

            // Second rotating ring (opposite)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(0.03),
                            Color(red: 0.45, green: 0.55, blue: 0.90).opacity(0.2),
                            .white.opacity(0.03),
                        ],
                        center: .center
                    ),
                    lineWidth: 1
                )
                .frame(width: breathe ? 155 : 125, height: breathe ? 155 : 125)
                .rotationEffect(.degrees(-ringRotation * 0.7))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)

            // Main breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.55, green: 0.45, blue: 0.85).opacity(0.6),
                            Color(red: 0.40, green: 0.30, blue: 0.70).opacity(0.3),
                            Color(red: 0.30, green: 0.20, blue: 0.55).opacity(0.1),
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 55
                    )
                )
                .frame(width: breathe ? 100 : 70, height: breathe ? 100 : 70)
                .shadow(color: Color(red: 0.50, green: 0.40, blue: 0.85).opacity(innerGlow ? 0.5 : 0.2), radius: innerGlow ? 30 : 15)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: innerGlow)

            // ── Cute mascot face ──
            MascotFace(eyesOpen: blinking)
                .frame(width: 60, height: 50)
                .scaleEffect(breathe ? 1.1 : 0.95)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)
        }
        .scaleEffect(logoIn ? 1 : 0.2)
        .opacity(logoIn ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: logoIn)
    }

    // MARK: - Sequence

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            impactMedium.impactOccurred()
            logoIn = true
            gradientPhase = true
            starsVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            breathe = true
            innerGlow = true
            ringRotation = 360
            startBlinking()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { titleIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { subtitleIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            impactLight.impactOccurred()
            buttonIn = true
        }
    }

    // MARK: - Blinking

    private func startBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            // Open eyes briefly
            withAnimation(.easeInOut(duration: 0.1)) { blinking = true }
            // Close again after a short moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.1)) { blinking = false }
            }
        }
    }
}

// MARK: - Mascot Face

private struct MascotFace: View {
    let eyesOpen: Bool

    var body: some View {
        ZStack {
            if eyesOpen {
                // Open eyes — round with pupils
                Group {
                    Circle().fill(.white.opacity(0.9)).frame(width: 8, height: 8).offset(x: -10, y: -4)
                    Circle().fill(.white.opacity(0.9)).frame(width: 8, height: 8).offset(x: 10, y: -4)
                    Circle().fill(Color(red: 0.20, green: 0.15, blue: 0.35)).frame(width: 4, height: 4).offset(x: -10, y: -4)
                    Circle().fill(Color(red: 0.20, green: 0.15, blue: 0.35)).frame(width: 4, height: 4).offset(x: 10, y: -4)
                    Circle().fill(.white).frame(width: 2, height: 2).offset(x: -8.5, y: -5)
                    Circle().fill(.white).frame(width: 2, height: 2).offset(x: 11.5, y: -5)
                }
            } else {
                // Closed eyes — peaceful curves
                ClosedEyes()
            }

            // Rosy cheeks
            Ellipse().fill(Color(red: 0.85, green: 0.55, blue: 0.70).opacity(0.45))
                .frame(width: 8, height: 5).offset(x: -16, y: 3)
            Ellipse().fill(Color(red: 0.85, green: 0.55, blue: 0.70).opacity(0.45))
                .frame(width: 8, height: 5).offset(x: 16, y: 3)

            // Smile
            SmilePath()
        }
    }
}

private struct ClosedEyes: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let style = StrokeStyle(lineWidth: 2, lineCap: .round)
            var left = Path()
            left.addArc(center: CGPoint(x: cx - 10, y: cy - 4), radius: 5,
                        startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(left, with: .color(.white.opacity(0.85)), style: style)
            var right = Path()
            right.addArc(center: CGPoint(x: cx + 10, y: cy - 4), radius: 5,
                         startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            context.stroke(right, with: .color(.white.opacity(0.85)), style: style)
        }
        .frame(width: 60, height: 50)
        .allowsHitTesting(false)
    }
}

private struct SmilePath: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            var smile = Path()
            smile.addArc(center: CGPoint(x: cx, y: cy + 4), radius: 6,
                         startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            context.stroke(smile, with: .color(.white.opacity(0.7)),
                          style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .frame(width: 60, height: 50)
        .allowsHitTesting(false)
    }
}

// MARK: - Button Style

private struct Duolingo3DButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.15, dampingFraction: 0.9), value: configuration.isPressed)
    }
}


#Preview {
    MeditationWelcomeView()
}
