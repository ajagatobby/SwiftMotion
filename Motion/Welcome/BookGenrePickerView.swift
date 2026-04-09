//
//  BookGenrePickerView.swift
//  BookApp
//
//  Book genre picker welcome screen with stamp-shaped
//  carousel cards and 3D perspective swipe

import SwiftUI

// MARK: - Book Genre Data

private struct BookGenre: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let icon: String
    let coverElements: [CoverElement]
}

private struct CoverElement: Identifiable {
    let id = UUID()
    let icon: String
    let size: CGFloat
    let offset: CGSize
    let color: Color
}

private let genres: [BookGenre] = [
    .init(name: "Fiction", color: Color(red: 0.85, green: 0.32, blue: 0.35), icon: "book.fill",
          coverElements: [
              .init(icon: "moon.stars.fill", size: 28, offset: CGSize(width: 0, height: -30), color: .yellow),
              .init(icon: "mountain.2.fill", size: 32, offset: CGSize(width: 0, height: 20), color: .white.opacity(0.5)),
              .init(icon: "sparkles", size: 14, offset: CGSize(width: -35, height: -15), color: .white.opacity(0.6)),
              .init(icon: "sparkles", size: 10, offset: CGSize(width: 30, height: 5), color: .white.opacity(0.4)),
          ]),
    .init(name: "Sci-Fi", color: Color(red: 0.25, green: 0.45, blue: 0.85), icon: "sparkles",
          coverElements: [
              .init(icon: "globe.americas.fill", size: 36, offset: CGSize(width: -8, height: -10), color: .cyan.opacity(0.7)),
              .init(icon: "star.fill", size: 12, offset: CGSize(width: 30, height: -30), color: .yellow),
              .init(icon: "star.fill", size: 8, offset: CGSize(width: -30, height: -35), color: .white.opacity(0.5)),
              .init(icon: "bolt.fill", size: 18, offset: CGSize(width: 25, height: 20), color: .orange),
              .init(icon: "sparkle", size: 10, offset: CGSize(width: -25, height: 25), color: .white.opacity(0.4)),
          ]),
    .init(name: "Romance", color: Color(red: 0.90, green: 0.45, blue: 0.55), icon: "heart.fill",
          coverElements: [
              .init(icon: "heart.fill", size: 30, offset: CGSize(width: 0, height: -15), color: .white.opacity(0.8)),
              .init(icon: "heart.fill", size: 16, offset: CGSize(width: 25, height: -30), color: .white.opacity(0.4)),
              .init(icon: "heart.fill", size: 12, offset: CGSize(width: -28, height: 5), color: .white.opacity(0.3)),
              .init(icon: "leaf.fill", size: 20, offset: CGSize(width: -10, height: 25), color: .green.opacity(0.5)),
              .init(icon: "sparkles", size: 12, offset: CGSize(width: 28, height: 15), color: .white.opacity(0.5)),
          ]),
    .init(name: "Mystery", color: Color(red: 0.22, green: 0.22, blue: 0.32), icon: "magnifyingglass",
          coverElements: [
              .init(icon: "magnifyingglass", size: 30, offset: CGSize(width: 5, height: -12), color: .white.opacity(0.7)),
              .init(icon: "questionmark", size: 22, offset: CGSize(width: -20, height: -25), color: .yellow.opacity(0.6)),
              .init(icon: "eye.fill", size: 18, offset: CGSize(width: 20, height: 15), color: .cyan.opacity(0.5)),
              .init(icon: "sparkle", size: 10, offset: CGSize(width: -25, height: 20), color: .white.opacity(0.3)),
          ]),
    .init(name: "Self-Help", color: Color(red: 0.95, green: 0.65, blue: 0.15), icon: "sun.max.fill",
          coverElements: [
              .init(icon: "sun.max.fill", size: 32, offset: CGSize(width: 0, height: -20), color: .white.opacity(0.8)),
              .init(icon: "arrow.up.right", size: 20, offset: CGSize(width: -20, height: 15), color: .white.opacity(0.5)),
              .init(icon: "brain.head.profile", size: 22, offset: CGSize(width: 18, height: 10), color: .white.opacity(0.4)),
              .init(icon: "sparkles", size: 12, offset: CGSize(width: 30, height: -25), color: .white.opacity(0.5)),
          ]),
]

// MARK: - Main Views

struct BookGenrePickerView: View {
    @State private var currentIndex = 1
    @State private var dragOffset: CGFloat = 0

    // ── entrance animation ──
    @State private var headerIn = false
    @State private var iconIn = false
    @State private var titleIn = false
    @State private var cardsIn = false
    @State private var footerIn = false
    @State private var logoTapped = false

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header (commented out) ──
                // headerBar
                //     .padding(.top, 12)

                Spacer().frame(height: 28)

                // ── Widget Icon ──
                widgetIcon
                    .padding(.bottom, 16)
                    .onTapGesture {
                        triggerLogoAnimation()
                    }

                // ── Title ──
                titleSection

                Spacer().frame(height: 32)

                // ── Card Carousel ──
                cardCarousel
                    .frame(height: 280)

                Spacer().frame(height: 20)

                // ── Swipe Indicator ──
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.4))
                    .opacity(footerIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: footerIn)

                Spacer().frame(height: 12)

                // ── Description ──
                Text("Swipe through and pick the genre that best\ndescribes what you love to read.")
                    .font(.custom("BricolageGrotesque24pt-Regular", size: 14))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(footerIn ? 1 : 0)
                    .offset(y: footerIn ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: footerIn)

                Spacer()

                // ── Fluffy Button — reacts to current genre ──
                Button(action: {}) {
                    Text("Continue")
                        .font(.custom("BricolageGrotesque24pt-Bold", size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                // Soft blurred glow — matches genre color
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(genres[currentIndex].color.opacity(0.4))
                                    .blur(radius: 8)
                                    .offset(y: 4)

                                // Main pill — genre color gradient
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(genres[currentIndex].color)

                                // Darker bottom half for depth
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.15)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                // Inner highlight
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.22), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(FluffyButtonStyle())
                .padding(.horizontal, 60)
                .padding(.bottom, 16)
                .opacity(footerIn ? 1 : 0)
                .offset(y: footerIn ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: footerIn)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
            }
        }
        .safeAreaPadding(.bottom)
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
            startSequence()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // Back button
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.gray.opacity(0.08)))
            }

            Spacer()

            // Skip button
            Button(action: {}) {
                Text("Skip")
                    .font(.custom("BricolageGrotesque24pt-SemiBold", size: 15))
                    .foregroundStyle(Color(red: 0.20, green: 0.65, blue: 0.45))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.20, green: 0.65, blue: 0.45).opacity(0.08))
                    )
            }
        }
        .padding(.horizontal, 20)
        .opacity(headerIn ? 1 : 0)
        .offset(y: headerIn ? 0 : -8)
        .animation(.easeOut(duration: 0.4), value: headerIn)
    }

    // MARK: - Widget Icon

    private var widgetIcon: some View {
        BookGenreLogo()
            .frame(width: 70, height: 75)
            .scaleEffect(iconIn ? (logoTapped ? 1.15 : 1) : 0.3)
            .rotationEffect(.degrees(logoTapped ? -8 : 0))
            .opacity(iconIn ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconIn)
            .animation(.spring(response: 0.3, dampingFraction: 0.4), value: logoTapped)
    }

    private func triggerLogoAnimation() {
        impactMedium.impactOccurred()
        logoTapped = true

        // Re-trigger page flip
        BookGenreLogo.triggerFlip?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            logoTapped = false
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text("Choose your")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 32))
                .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.18))
            Text("favorite genre")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 32))
                .foregroundStyle(Color(red: 0.10, green: 0.12, blue: 0.18))
        }
        .multilineTextAlignment(.center)
        .opacity(titleIn ? 1 : 0)
        .offset(y: titleIn ? 0 : 15)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: titleIn)
    }

    // MARK: - Card Carousel

    private var cardCarousel: some View {
        GeometryReader { geo in
            let cardWidth: CGFloat = 210
            let screenW = geo.size.width

            ZStack {
                ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                    let diff = CGFloat(index - currentIndex)
                    let dragNorm = dragOffset / screenW
                    let pos = diff + dragNorm

                    // Fan from bottom: left tilts right, right tilts left
                    let tilt = pos * 18
                    let xShift = pos * screenW * 0.52
                    let scale = max(0.8, 1.0 - abs(pos) * 0.08)
                    let yShift = abs(pos) * 15

                    stampCard(genre: genre)
                        .frame(width: cardWidth)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(tilt), anchor: .bottom)
                        .offset(x: xShift, y: yShift)
                        .zIndex(Double(10 - abs(index - currentIndex)))
                        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: currentIndex)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: dragOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold && currentIndex < genres.count - 1 {
                            impactLight.impactOccurred()
                            currentIndex += 1
                        } else if value.translation.width > threshold && currentIndex > 0 {
                            impactLight.impactOccurred()
                            currentIndex -= 1
                        }
                        dragOffset = 0
                    }
            )
        }
        .opacity(cardsIn ? 1 : 0)
        .scaleEffect(cardsIn ? 1 : 0.85)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: cardsIn)
    }

    // MARK: - Stamp Card

    private func stampCard(genre: BookGenre) -> some View {
        VStack(spacing: 0) {
            // Stamp body
            ZStack {
                // Stamp background with scalloped edges
                StampShape()
                    .fill(genre.color.opacity(0.12))
                    .shadow(color: genre.color.opacity(0.08), radius: 8, y: 4)

                // Book cover
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(genre.color)

                    // Cover illustration elements
                    ForEach(genre.coverElements) { el in
                        Image(systemName: el.icon)
                            .font(.system(size: el.size, weight: .semibold))
                            .foregroundStyle(el.color)
                            .offset(el.offset)
                    }

                    // Sparkle decorations
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(x: -50, y: -60)
                    Image(systemName: "sparkle")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .offset(x: 50, y: -45)
                    Image(systemName: "sparkle")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                        .offset(x: -40, y: 45)
                    Image(systemName: "sparkle")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .offset(x: 45, y: 35)
                }
                .padding(14)
            }

            // Genre label below stamp
            Text(genre.name)
                .font(.custom("BricolageGrotesque72pt-Bold", size: 20))
                .foregroundStyle(genre.color)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Sequence

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { headerIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            impactMedium.impactOccurred()
            iconIn = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { titleIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            impactLight.impactOccurred()
            cardsIn = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { footerIn = true }
    }
}

// MARK: - Stamp Shape (scalloped edges)

private struct StampShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 4.5     // scallop radius
        let margin: CGFloat = 8  // corner margin

        var path = Path()

        // ── Top edge: left to right ──
        path.move(to: CGPoint(x: rect.minX + margin, y: rect.minY))
        let topCount = Int((rect.width - margin * 2) / (r * 2.5))
        let topSpacing = (rect.width - margin * 2) / CGFloat(topCount)
        for i in 0..<topCount {
            let cx = rect.minX + margin + topSpacing * (CGFloat(i) + 0.5)
            path.addLine(to: CGPoint(x: cx - r, y: rect.minY))
            path.addArc(center: CGPoint(x: cx, y: rect.minY),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.minY))

        // ── Right edge: top to bottom ──
        let rightCount = Int((rect.height - margin * 2) / (r * 2.5))
        let rightSpacing = (rect.height - margin * 2) / CGFloat(rightCount)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + margin))
        for i in 0..<rightCount {
            let cy = rect.minY + margin + rightSpacing * (CGFloat(i) + 0.5)
            path.addLine(to: CGPoint(x: rect.maxX, y: cy - r))
            path.addArc(center: CGPoint(x: rect.maxX, y: cy),
                        radius: r, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - margin))

        // ── Bottom edge: right to left ──
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.maxY))
        for i in stride(from: topCount - 1, through: 0, by: -1) {
            let cx = rect.minX + margin + topSpacing * (CGFloat(i) + 0.5)
            path.addLine(to: CGPoint(x: cx + r, y: rect.maxY))
            path.addArc(center: CGPoint(x: cx, y: rect.maxY),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.minX + margin, y: rect.maxY))

        // ── Left edge: bottom to top ──
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - margin))
        for i in stride(from: rightCount - 1, through: 0, by: -1) {
            let cy = rect.minY + margin + rightSpacing * (CGFloat(i) + 0.5)
            path.addLine(to: CGPoint(x: rect.minX, y: cy + r))
            path.addArc(center: CGPoint(x: rect.minX, y: cy),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + margin))

        path.closeSubpath()
        return path
    }
}


// MARK: - Animated Book Logo with Page Flip

private struct BookGenreLogo: View {
    static var triggerFlip: (() -> Void)?

    @State private var pageFlip1: Double = 0
    @State private var pageFlip2: Double = 0
    @State private var pageFlip3: Double = 0

    private let bookBlue = Color(red: 0.25, green: 0.45, blue: 0.85)
    private let bookRed = Color(red: 0.85, green: 0.32, blue: 0.35)

    var body: some View {
        ZStack {
            // ── Book cover (back) ──
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(bookBlue.opacity(0.3))
                .frame(width: 40, height: 48)
                .rotationEffect(.degrees(-6))
                .offset(x: -3, y: 2)

            // ── Book cover (front) ──
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(bookBlue)
                .frame(width: 40, height: 48)
                .overlay(
                    // Spine
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                )

            // ── Flipping pages ──
            // Page 3 (flips first)
            pageView(color: .white.opacity(0.95))
                .rotation3DEffect(
                    .degrees(pageFlip3),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.4
                )

            // Page 2
            pageView(color: Color(red: 0.96, green: 0.94, blue: 0.90))
                .rotation3DEffect(
                    .degrees(pageFlip2),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.4
                )

            // Page 1 (flips last)
            pageView(color: Color(red: 0.98, green: 0.96, blue: 0.92))
                .rotation3DEffect(
                    .degrees(pageFlip1),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.4
                )

        }
        .onAppear {
            startPageFlip()
            BookGenreLogo.triggerFlip = {
                // Reset pages then flip again
                pageFlip1 = 0
                pageFlip2 = 0
                pageFlip3 = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startPageFlip()
                }
            }
        }
    }

    private func pageView(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 28, height: 40)
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.gray.opacity(0.15))
                            .frame(height: 2)
                    }
                    Spacer()
                }
                .padding(6)
            )
            .offset(x: 2)
    }

    private func startPageFlip() {
        withAnimation(.easeInOut(duration: 0.6).delay(0.6)) {
            pageFlip3 = -160
        }
        withAnimation(.easeInOut(duration: 0.6).delay(1.0)) {
            pageFlip2 = -155
        }
        withAnimation(.easeInOut(duration: 0.6).delay(1.4)) {
            pageFlip1 = -150
        }
        // Flip back
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.5)) { pageFlip1 = 0 }
            withAnimation(.easeInOut(duration: 0.5).delay(0.15)) { pageFlip2 = 0 }
            withAnimation(.easeInOut(duration: 0.5).delay(0.3)) { pageFlip3 = 0 }
        }
    }
}

// MARK: - Fluffy Button Style

private struct FluffyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    BookGenrePickerView()
}
