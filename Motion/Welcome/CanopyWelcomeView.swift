//
//  CanopyWelcomeView.swift
//  Motion
//
//  Canopi-style welcome screen with feature card carousel,
//  soft gradient background, and Sign in with Apple button.

import SwiftUI

// MARK: - Feature Card Data

private struct FeatureCard: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let style: CardStyle
}

private enum CardStyle {
    case photo, tasks, website, location, notes
}

private let featureCards: [FeatureCard] = [
    .init(name: "Location", icon: "map.fill", color: Color(red: 0.40, green: 0.72, blue: 0.45), style: .location),
    .init(name: "Tasks", icon: "checklist", color: .white, style: .tasks),
    .init(name: "Photo", icon: "photo.fill", color: Color(red: 0.45, green: 0.82, blue: 0.88), style: .photo),
    .init(name: "Website", icon: "safari.fill", color: .white, style: .website),
    .init(name: "Notes", icon: "note.text", color: Color(red: 0.95, green: 0.85, blue: 0.35), style: .notes),
]

// MARK: - Main View

struct CanopyWelcomeView: View {

    // ── animation state ──
    @State private var logoIn = false
    @State private var titleIn = false
    @State private var subtitleIn = false
    @State private var cardsIn = false
    @State private var buttonIn = false
    @State private var gradientShift = false
    @State private var marqueeStartTime: Date?

    // ── magnet text ──
    @State private var magnetAnimator = MagnetAnimator()
    @State private var magnetTimer: Timer?

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            // ── Gradient Background ──
            backgroundGradient

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ──
                canopyLogo
                    .padding(.bottom, 20)

                // ── Title ──
                VStack(spacing: 6) {
                    Text("Welcome to")
                        .font(.custom("BricolageGrotesque24pt-Regular", size: 18))
                        .foregroundStyle(Color(red: 0.60, green: 0.55, blue: 0.70))

                    Text("Glimpse")
                        .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 48))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .distortionEffect(
                            ShaderLibrary.magnetEffect(
                                .float2(magnetAnimator.currentPos),
                                .float(magnetAnimator.currentStrength),
                                .float(120)
                            ),
                            maxSampleOffset: CGSize(width: 150, height: 150)
                        )
                }
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn ? 0 : 12)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: titleIn)

                // ── Subtitle ──
                Text("Capture and share moments\nthat matter most.")
                    .font(.custom("BricolageGrotesque24pt-Regular", size: 16))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 14)
                    .opacity(subtitleIn ? 1 : 0)
                    .offset(y: subtitleIn ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: subtitleIn)

                Spacer().frame(height: 36)

                // ── Feature Cards Carousel ──
                cardCarousel
                    .frame(height: 160)
                    .opacity(cardsIn ? 1 : 0)
                    .offset(y: cardsIn ? 0 : 40)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75), value: cardsIn)

                Spacer()

                // ── Sign in Button ──
                signInButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    .opacity(buttonIn ? 1 : 0)
                    .offset(y: buttonIn ? 0 : 30)
                    .animation(.spring(response: 0.55, dampingFraction: 0.7), value: buttonIn)
            }
        }
        .safeAreaPadding(.bottom)
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
            startSequence()
        }
        .onDisappear {
            magnetTimer?.invalidate()
            magnetAnimator.stop()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 0.95, green: 0.88, blue: 0.85).opacity(gradientShift ? 0.5 : 0.2),
                    Color(red: 0.88, green: 0.85, blue: 0.95).opacity(gradientShift ? 0.45 : 0.15),
                    Color(red: 0.85, green: 0.90, blue: 0.98).opacity(gradientShift ? 0.3 : 0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: gradientShift)
        }
    }

    // MARK: - Logo

    private var canopyLogo: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2

            // ── Outer eye shape ──
            var eye = Path()
            eye.move(to: CGPoint(x: cx - 20, y: cy))
            eye.addQuadCurve(
                to: CGPoint(x: cx + 20, y: cy),
                control: CGPoint(x: cx, y: cy - 18)
            )
            eye.addQuadCurve(
                to: CGPoint(x: cx - 20, y: cy),
                control: CGPoint(x: cx, y: cy + 18)
            )
            context.stroke(eye, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            // ── Iris ring ──
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - 9, y: cy - 9, width: 18, height: 18)),
                with: .color(.black),
                lineWidth: 2.5
            )

            // ── Pupil ──
            context.fill(
                Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)),
                with: .color(.black)
            )

            // ── Catchlight (reflection dot) ──
            context.fill(
                Path(ellipseIn: CGRect(x: cx + 1, y: cy - 3, width: 3, height: 3)),
                with: .color(.white)
            )

            // ── Viewfinder corners ──
            let cornerLen: CGFloat = 5
            let inset: CGFloat = 4
            let style = StrokeStyle(lineWidth: 2, lineCap: .round)

            // Top-left
            var tl = Path()
            tl.move(to: CGPoint(x: cx - 20 + inset, y: cy - 14))
            tl.addLine(to: CGPoint(x: cx - 20 + inset, y: cy - 14 - cornerLen))
            tl.move(to: CGPoint(x: cx - 20 + inset, y: cy - 14))
            tl.addLine(to: CGPoint(x: cx - 20 + inset + cornerLen, y: cy - 14))
            context.stroke(tl, with: .color(.black.opacity(0.3)), style: style)

            // Top-right
            var tr = Path()
            tr.move(to: CGPoint(x: cx + 20 - inset, y: cy - 14))
            tr.addLine(to: CGPoint(x: cx + 20 - inset, y: cy - 14 - cornerLen))
            tr.move(to: CGPoint(x: cx + 20 - inset, y: cy - 14))
            tr.addLine(to: CGPoint(x: cx + 20 - inset - cornerLen, y: cy - 14))
            context.stroke(tr, with: .color(.black.opacity(0.3)), style: style)

            // Bottom-left
            var bl = Path()
            bl.move(to: CGPoint(x: cx - 20 + inset, y: cy + 14))
            bl.addLine(to: CGPoint(x: cx - 20 + inset, y: cy + 14 + cornerLen))
            bl.move(to: CGPoint(x: cx - 20 + inset, y: cy + 14))
            bl.addLine(to: CGPoint(x: cx - 20 + inset + cornerLen, y: cy + 14))
            context.stroke(bl, with: .color(.black.opacity(0.3)), style: style)

            // Bottom-right
            var br = Path()
            br.move(to: CGPoint(x: cx + 20 - inset, y: cy + 14))
            br.addLine(to: CGPoint(x: cx + 20 - inset, y: cy + 14 + cornerLen))
            br.move(to: CGPoint(x: cx + 20 - inset, y: cy + 14))
            br.addLine(to: CGPoint(x: cx + 20 - inset - cornerLen, y: cy + 14))
            context.stroke(br, with: .color(.black.opacity(0.3)), style: style)
        }
        .frame(width: 50, height: 44)
        .scaleEffect(logoIn ? 1 : 0.3)
        .opacity(logoIn ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: logoIn)
    }

    // MARK: - Card Carousel

    // Total width of one set of cards
    private var oneSetWidth: CGFloat {
        let cardW: CGFloat = 85
        let spacing: CGFloat = 14
        return CGFloat(featureCards.count) * (cardW + spacing)
    }

    private var cardCarousel: some View {
        TimelineView(.animation) { timeline in
            let offset: CGFloat = {
                guard let start = marqueeStartTime else { return 40 }
                let elapsed = timeline.date.timeIntervalSince(start)
                let speed: CGFloat = 40 // points per second
                let raw = 40 - CGFloat(elapsed) * speed
                return raw.truncatingRemainder(dividingBy: oneSetWidth) - (raw < -oneSetWidth ? 0 : 0)
            }()
            // Use modulo to seamlessly wrap
            let wrappedOffset = ((offset.truncatingRemainder(dividingBy: oneSetWidth)) + oneSetWidth).truncatingRemainder(dividingBy: oneSetWidth) - oneSetWidth + 40

            GeometryReader { geo in
                HStack(spacing: 14) {
                    // First set
                    ForEach(Array(featureCards.enumerated()), id: \.element.id) { index, card in
                        let staggerY: [CGFloat] = [18, 8, 0, 8, 18]
                        featureCardView(card: card, index: index)
                            .offset(y: cardsIn ? staggerY[index] : CGFloat(index) * 8 + 30)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.08),
                                value: cardsIn
                            )
                    }

                    // Duplicate set for seamless loop
                    ForEach(Array(featureCards.enumerated()), id: \.element.id) { index, card in
                        let staggerY: [CGFloat] = [18, 8, 0, 8, 18]
                        featureCardView(card: card, index: index)
                            .offset(y: cardsIn ? staggerY[index] : CGFloat(index) * 8 + 30)
                    }
                }
                .padding(.vertical, 10)
                .offset(x: wrappedOffset)
            }
        }
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 50)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 50)
            }
        )
    }

    private func startMarquee() {
        marqueeStartTime = Date()
    }

    private func featureCardView(card: FeatureCard, index: Int) -> some View {
        let isCenter = index == 2
        let cardWidth: CGFloat = 85
        let cardHeight: CGFloat = 100

        return ZStack {
            // Card face
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card.color)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)

                // Card content based on style
                cardContent(style: card.style)

                // Label at bottom inside card
                VStack {
                    Spacer()
                    Text(card.name)
                        .font(.custom("BricolageGrotesque24pt-SemiBold", size: 12))
                        .foregroundStyle(card.style == .photo || card.style == .location ? .white : .black.opacity(0.6))
                        .shadow(color: card.style == .photo || card.style == .location ? .black.opacity(0.4) : .clear, radius: 2, y: 1)
                        .padding(.bottom, 8)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private func cardContent(style: CardStyle) -> some View {
        switch style {
        case .tasks:
            tasksCardContent
        case .photo:
            photoCardContent
        case .website:
            websiteCardContent
        case .location:
            locationCardContent
        case .notes:
            notesCardContent
        }
    }

    // MARK: - Card Content Views

    private var tasksCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            taskRow(checked: false)
            taskRow(checked: true)
            taskRow(checked: false)
            Spacer()
        }
        .padding(12)
    }

    private func taskRow(checked: Bool) -> some View {
        HStack(spacing: 8) {
            // Checkbox circle
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                .frame(width: 16, height: 16)
                .overlay(
                    checked ?
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.5))
                    : nil
                )

            // Gray bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.18))
                .frame(width: 30, height: 5)
        }
    }

    private var photoCardContent: some View {
        GeometryReader { geo in
            Image("bridge")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var websiteCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icons top right
            HStack(spacing: 10) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.45))
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.45))
            }

            // Content lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.15)).frame(height: 5)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.12)).frame(width: 55, height: 5)
                RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.10)).frame(height: 5)
            }

            Spacer()
        }
        .padding(12)
    }

    private var locationCardContent: some View {
        ZStack {
            // Map-like gradient
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.90, blue: 0.78),
                    Color(red: 0.75, green: 0.85, blue: 0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Map pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
                .offset(x: 5, y: -5)

            // Roads
            Path { p in
                p.move(to: CGPoint(x: 0, y: 60))
                p.addLine(to: CGPoint(x: 120, y: 40))
            }
            .stroke(.white.opacity(0.4), lineWidth: 2)

            Path { p in
                p.move(to: CGPoint(x: 30, y: 0))
                p.addLine(to: CGPoint(x: 50, y: 150))
            }
            .stroke(.white.opacity(0.3), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(2)
    }

    private var notesCardContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.15)).frame(width: 60, height: 6)
            RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.10)).frame(height: 4)
            RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.10)).frame(width: 70, height: 4)
            RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.08)).frame(height: 4)
            RoundedRectangle(cornerRadius: 2).fill(.black.opacity(0.08)).frame(width: 50, height: 4)
        }
        .padding(14)
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .semibold))
                Text("Sign in with Apple")
                    .font(.custom("BricolageGrotesque24pt-SemiBold", size: 17))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(.black)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(CanopyButtonStyle())
    }

    // MARK: - Sequence

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactMedium.impactOccurred()
            logoIn = true
            gradientShift = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            titleIn = true
            magnetAnimator.start()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { subtitleIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { startAutoMagnet() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            impactLight.impactOccurred()
            cardsIn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                startMarquee()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            impactLight.impactOccurred()
            buttonIn = true
        }
    }

    // MARK: - Auto Magnet Animation

    private func startAutoMagnet() {
        // Simulate a magnetic point sweeping across the text
        var elapsed: Double = 0
        magnetAnimator.beginDrag()

        magnetTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            elapsed += 1.0 / 60.0

            // Sweep the magnet point in a smooth figure-8 / lemniscate path
            let t = elapsed * 0.8
            let x = 160 + sin(t) * 100
            let y = 40 + sin(t * 2) * 20

            magnetAnimator.targetPos = CGPoint(x: x, y: y)
            magnetAnimator.targetStrength = 0.4 + sin(elapsed * 1.5) * 0.2
        }
    }
}

extension CanopyWelcomeView {
    func cleanupTimers() {
        magnetTimer?.invalidate()
        magnetAnimator.stop()
    }
}

// MARK: - Button Style

private struct CanopyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    CanopyWelcomeView()
}
