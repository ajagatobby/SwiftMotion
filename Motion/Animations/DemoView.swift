//
//  DemoView.swift
//  Motion

import SwiftUI
import Combine

// MARK: - Animation item model

struct AnimationItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let category: AnimationCategory
    let destination: AnyView
}

enum AnimationCategory: String, CaseIterable {
    case text = "Text"
    case image = "Image"
    case games = "Games"
    case special = "Special"
}

// MARK: - Demo View

struct DemoView: View {

    @State private var appeared = false
    @State private var titleScale: CGFloat = 0.8
    @State private var titleOpacity: CGFloat = 0.0
    @State private var subtitleOpacity: CGFloat = 0.0
    @State private var visibleCardCount = 0
    @State private var selectedCategory: AnimationCategory = .text
    @Namespace private var tabNamespace

    private let items: [AnimationItem] = {
        var list = [AnimationItem]()

        // Text Animations
        let textItems: [(String, String, AnyView)] = [
            ("Liquid", "drop.fill", AnyView(LiquidTextView())),
            ("Stretchy", "hand.draw.fill", AnyView(StretchyTextView())),
            ("Wave", "water.waves", AnyView(WaveTextView())),
            ("Glitch", "bolt.fill", AnyView(GlitchTextView())),
            ("Magnet", "pin.fill", AnyView(MagnetTextView())),
            ("Vortex", "hurricane", AnyView(VortexTextView())),
            ("Typewriter", "character.cursor.ibeam", AnyView(TypewriterTextView())),
            ("Scramble", "textformat.abc", AnyView(ScrambleTextView())),
            ("Shatter", "square.grid.3x3.topleft.filled", AnyView(SplitShatterTextView())),
            ("Kinetic", "figure.walk", AnyView(KineticTextView())),
            ("Flip", "rectangle.portrait.rotate", AnyView(FlipRevealTextView())),
            ("Morphing", "arrow.triangle.2.circlepath", AnyView(MorphingTextView())),
            ("Burn", "flame.fill", AnyView(BurnDissolveTextView())),
            ("Pixel Sort", "line.3.horizontal.decrease", AnyView(PixelSortTextView())),
            ("Chrome", "sparkles", AnyView(ChromeTextView())),
        ]
        for (name, icon, dest) in textItems {
            list.append(AnimationItem(name: name, icon: icon, category: .text, destination: dest))
        }

        // Image Animations
        let imageItems: [(String, String, AnyView)] = [
            ("Frozen", "snowflake", AnyView(FrozenImageView())),
            ("Liquid", "drop.fill", AnyView(LiquidImageView())),
            ("Parallax", "gyroscope", AnyView(ParallaxImageView())),
            ("Water", "water.waves", AnyView(WaterReflectionView())),
            ("Halftone", "circle.grid.3x3.fill", AnyView(HalftoneImageView())),
            ("Chromatic", "camera.filters", AnyView(ChromaticImageView())),
            ("Morph", "wand.and.stars", AnyView(MorphImageView())),
            ("Dissolve", "sparkle", AnyView(NoiseDissolveView())),
            ("Duotone", "paintpalette.fill", AnyView(DuotoneImageView())),
            ("Scratch", "hand.draw.fill", AnyView(ScratchRevealView())),
            ("Compare", "slider.horizontal.below.rectangle", AnyView(BeforeAfterView())),
            ("Zoom Lens", "magnifyingglass", AnyView(ZoomLensImageView())),
            ("Card Flip", "rectangle.portrait.on.rectangle.portrait.fill", AnyView(CardFlipImageView())),
        ]
        for (name, icon, dest) in imageItems {
            list.append(AnimationItem(name: name, icon: icon, category: .image, destination: dest))
        }

        // Games
        let gameItems: [(String, String, AnyView)] = [
            ("Magic Tiles", "pianokeys", AnyView(MagicTilesView())),
            ("Dither Dash", "gamecontroller.fill", AnyView(DitherDashView())),
            ("Color Tap", "hand.tap.fill", AnyView(ColorTapView())),

            ("Neon Snake", "poweroutlet.type.l.fill", AnyView(NeonSnakeView())),
        ]
        for (name, icon, dest) in gameItems {
            list.append(AnimationItem(name: name, icon: icon, category: .games, destination: dest))
        }

        // Special Animations
        let specialItems: [(String, String, AnyView)] = [
            ("Black Hole", "circle.fill", AnyView(BlackHoleView())),
            ("Earth Globe", "globe.americas.fill", AnyView(EarthGlobeView())),
            ("Dither", "circle.grid.3x3.fill", AnyView(DitherView())),
            ("Coin Flip", "centsign.circle.fill", AnyView(CoinFlipView())),
            ("Book", "book.fill", AnyView(Book())),
            ("Audio Wave", "waveform", AnyView(AudioWavePlayerView())),
            ("Paper", "doc.richtext", AnyView(PaperSheetView())),
            ("3D Button", "cube.fill", AnyView(ButtonDemoWrapper { Duolingo3DButton(title: "Continue", color: Color(red: 0.35, green: 0.78, blue: 0.35)) {} })),
            ("Jelly", "drop.fill", AnyView(ButtonDemoWrapper { JellyButton(title: "Tap Me", color: .blue) {} })),
            ("Magnetic", "move.3d", AnyView(ButtonDemoWrapper { MagneticButton(title: "Hold & Drag", color: .purple) {} })),
            ("Liquid Fill", "hourglass.bottomhalf.filled", AnyView(ButtonDemoWrapper { LiquidFillButton(title: "Hold to Confirm", color: .orange) {} })),
            ("Neon Glow", "lightbulb.fill", AnyView(ButtonDemoWrapper { NeonGlowButton(title: "Glow", color: .cyan) {} })),
            ("Elastic Pill", "capsule.fill", AnyView(ButtonDemoWrapper { ElasticPillButton(title: "Subscribe", icon: "bell.fill", color: .pink) {} })),
            ("Hot Dog", "flame.fill", AnyView(HotDogView())),
            ("3D Jiggle", "rotate.3d", AnyView(JigglyModelView())),
            ("FoodPal V1", "fork.knife", AnyView(FoodPalWelcomeView())),
            ("FoodPal V2", "leaf.fill", AnyView(FoodPalWelcomeV2View())),
            ("Book Picker", "book.fill", AnyView(BookGenrePickerView())),
            ("Glimpse", "eye.fill", AnyView(CanopyWelcomeView())),
            ("Meditation", "sparkles", AnyView(MeditationWelcomeView())),
        ]
        for (name, icon, dest) in specialItems {
            list.append(AnimationItem(name: name, icon: icon, category: .special, destination: dest))
        }

        return list
    }()

    private var filteredItems: [AnimationItem] {
        items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 70)

                        animationGrid
                            .padding(.top, 24)
                            .padding(.bottom, 120)
                    }
                }

                customTabBar
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .onAppear { triggerEntrance() }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AnimationCategory.allCases, id: \.self) { category in
                tabItem(category: category)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 48)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.04), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
        .opacity(subtitleOpacity)
    }

    private func tabItem(category: AnimationCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
                visibleCardCount = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                staggerCards()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(.black.opacity(0.08))
                            .frame(width: 56, height: 30)
                            .matchedGeometryEffect(id: "tab_indicator", in: tabNamespace)
                    }

                    Image(systemName: tabIcon(category))
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .symbolEffect(.bounce, value: isSelected)
                }
                .frame(height: 30)

                Text(category.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .black : .black.opacity(0.3))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func tabIcon(_ category: AnimationCategory) -> String {
        switch category {
        case .text: return "textformat"
        case .image: return "photo"
        case .games: return "gamecontroller.fill"
        case .special: return "star.fill"
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Motion")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 52))
                .foregroundStyle(.black)
                .scaleEffect(titleScale)
                .opacity(titleOpacity)

            Text("A collection of SwiftUI + Metal animations")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.4))
                .opacity(subtitleOpacity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }


    // MARK: - Animation Grid

    private var animationGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                NavigationLink(destination: item.destination.navigationBarBackButtonHidden(false)) {
                    animationCard(item: item, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func animationCard(item: AnimationItem, index: Int) -> some View {
        let isVisible = index < visibleCardCount

        return VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    )

                Image(systemName: item.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .frame(height: 100)

            Text(item.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.7))
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .scaleEffect(isVisible ? 1 : 0.92)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.3), trigger: isVisible)
    }

    // MARK: - Entrance & Stagger

    private func triggerEntrance() {
        guard !appeared else { return }
        appeared = true

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
            subtitleOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            staggerCards()
        }
    }

    private func staggerCards() {
        let total = filteredItems.count
        for i in 0...total {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    visibleCardCount = i + 1
                }
            }
        }
    }
}

#Preview {
    DemoView()
}
