//
//  FoodPalWelcomeV2View.swift
//  Motion
//
//  Warm cream editorial welcome screen for FoodPal.
//  Paginated mockup carousel with 3 slides, cycling subtitle, dark olive CTA.

import SwiftUI
import Combine

// MARK: - Slide Data

private struct SlideData {
    let headline: String
    let subtitle: String
    let emoji: String
}

private let slides: [SlideData] = [
    .init(headline: "The easiest way to...", subtitle: "Track what you eat", emoji: "🍌"),
    .init(headline: "Your personal...", subtitle: "AI nutrition coach", emoji: "🧠"),
    .init(headline: "Stay on top of...", subtitle: "Your daily goals", emoji: "🎯"),
]

// MARK: - Colors

private extension Color {
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let oliveGreen = Color(red: 0.24, green: 0.28, blue: 0.18)
    static let warmBrown = Color(red: 0.30, green: 0.22, blue: 0.15)
    static let macroProt = Color(red: 0.92, green: 0.38, blue: 0.22)
    static let macroCarb = Color(red: 0.65, green: 0.78, blue: 0.18)
    static let macroFat = Color(red: 0.95, green: 0.72, blue: 0.15)
}

// MARK: - Main View

struct FoodPalWelcomeV2View: View {

    // ── page state ──
    @State private var currentPage = 0

    // ── animation state ──
    @State private var heroCardIn = false
    @State private var calorieCount: Int = 0
    @State private var proteinIn = false
    @State private var fatIn = false
    @State private var carbIn = false
    @State private var legendIn = false
    @State private var headlineIn = false
    @State private var subtitleIn = false
    @State private var dotsIn = false
    @State private var ctaIn = false
    @State private var headerIn = false
    @State private var logoBreathe = false
    @State private var bubblesFloat = false
    @State private var ctaGlow = false
    @State private var skeletonShimmer = false
    @State private var skeletonGrown = false
    @State private var bottomBlur: CGFloat = 20
    @State private var cardBlur: CGFloat = 4
    @State private var autoSlideTimer: AnyCancellable?

    // ── slide 2 state ──
    @State private var journalTextVisible = 0
    @State private var journalTimer: AnyCancellable?

    // ── slide 3 state ──
    @State private var stepsProgress: CGFloat = 0
    @State private var waterProgress: CGFloat = 0
    @State private var caloriesProgress: CGFloat = 0
    @State private var sleepProgress: CGFloat = 0
    @State private var goalsAnimated = false

    // ── calorie counter ──
    @State private var calorieTimer: AnyCancellable?

    // ── ring animation ──
    @State private var ringProgress: CGFloat = 0

    // ── slide heights ──
    private var slideHeight: CGFloat {
        switch currentPage {
        case 0: return 340
        case 1: return 440
        case 2: return 360
        default: return 380
        }
    }

    // ── haptics ──
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                headerBar
                    .padding(.top, 8)

                Spacer()

                // ── Paginated Mockup Cards ──
                ZStack {
                    ForEach(0..<3) { i in
                        Group {
                            if i == 0 { mockupSlide1 }
                            else if i == 1 { mockupSlide2 }
                            else { mockupSlide3 }
                        }
                        .opacity(currentPage == i ? 1 : 0)
                        .scaleEffect(currentPage == i ? 1.0 : 0.88)
                        .offset(y: currentPage == i ? 0 : 20)
                        .blur(radius: currentPage == i ? 0 : 6)
                    }
                }
                .frame(height: slideHeight)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: currentPage)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -30 && currentPage < 2 {
                                currentPage += 1
                            } else if value.translation.width > 30 && currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                )
                .padding(.horizontal, 8)

                Spacer()

                // ── Bottom content ──
                VStack(spacing: 0) {
                    // Headline
                    Text(slides[currentPage].headline)
                        .font(.custom("BricolageGrotesque72pt-Bold", size: 28))
                        .foregroundStyle(Color.warmBrown)
                        .contentTransition(.numericText())
                        .opacity(headlineIn ? 1 : 0)
                        .offset(y: headlineIn ? 0 : 15)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: headlineIn)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

                    // Subtitle Pill
                    ZStack {
                        ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                            if index == currentPage {
                                HStack(spacing: 6) {
                                    Text(slide.subtitle)
                                        .font(.custom("BricolageGrotesque24pt-Medium", size: 15))
                                        .foregroundStyle(Color.warmBrown)
                                    Text(slide.emoji)
                                        .font(.system(size: 16))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .modifier(
                                            active: ChipTransitionModifier(offset: 40, blur: 8, scale: 0.85),
                                            identity: ChipTransitionModifier(offset: 0, blur: 0, scale: 1.0)
                                        ),
                                        removal: .modifier(
                                            active: ChipTransitionModifier(offset: -40, blur: 8, scale: 0.85),
                                            identity: ChipTransitionModifier(offset: 0, blur: 0, scale: 1.0)
                                        )
                                    )
                                )
                            }
                        }
                    }
                    .padding(.top, 14)
                    .opacity(subtitleIn ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: subtitleIn)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: currentPage)

                    // Page Dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(i == currentPage ? Color.oliveGreen : Color.gray.opacity(0.3))
                                .frame(width: i == currentPage ? 10 : 8, height: i == currentPage ? 10 : 8)
                                .scaleEffect(i == currentPage ? 1.0 : 0.85)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: currentPage)
                        }
                    }
                    .padding(.top, 22)
                    .opacity(dotsIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: dotsIn)

                    // CTA
                    ctaButton
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                }
                .blur(radius: bottomBlur)
                .animation(.easeOut(duration: 0.8), value: bottomBlur)
            }
            .safeAreaPadding(.bottom)
        }
        .onAppear {
            impactLight.prepare()
            impactMedium.prepare()
            startSequence()
        }
        .onDisappear {
            calorieTimer?.cancel()
            journalTimer?.cancel()
            autoSlideTimer?.cancel()
        }
        .onChange(of: currentPage) { _, newPage in
            impactLight.impactOccurred()
            startAutoSlide()
            if newPage == 1 {
                startJournalTypewriter()
                skeletonGrown = true
                schedule(0.8) { skeletonShimmer = true }
            }
            if newPage == 2 { startGoalCounters() }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ZStack {
            // Centered logo
            FoodPalLogo()

            // Sign in aligned right
            HStack {
                Spacer()
                Text("Sign in")
                    .font(.custom("BricolageGrotesque24pt-Medium", size: 15))
                    .foregroundStyle(Color.oliveGreen)
            }
        }
        .padding(.horizontal, 20)
        .opacity(headerIn ? 1 : 0)
        .offset(y: headerIn ? 0 : -10)
        .animation(.easeOut(duration: 0.5), value: headerIn)
    }

    // MARK: - Slide 1: Calorie Tracker

    private var mockupSlide1: some View {
        calorieSection
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
            )
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .blur(radius: cardBlur)
            .offset(y: heroCardIn ? 0 : -30)
            .opacity(heroCardIn ? 1 : 0)
            .animation(.spring(response: 0.7, dampingFraction: 0.75), value: heroCardIn)
            .animation(.easeOut(duration: 0.8), value: cardBlur)
    }

    // MARK: - Slide 2: Journal Entry / AI Coach

    private let journalQuestion = "Eating well but dragging at the gym. What am I missing?"

    private var mockupSlide2: some View {
        let innerContent = journalInnerContent
        let outerCard = innerContent
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
            )
            .padding(8)

        return outerCard
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
    }

    private var journalInnerContent: some View {
        VStack(spacing: 0) {
            journalHeader
            journalQuestionCard
                .padding(.horizontal, 12)
            journalSkeletonBars
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: journalTextVisible)
    }

    private var journalHeader: some View {
        HStack {
            Spacer()
            Text("Journal Entry")
                .font(.custom("BricolageGrotesque24pt-SemiBold", size: 15))
                .foregroundStyle(Color.warmBrown)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.warmBrown.opacity(0.5))
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.warmBrown.opacity(0.5))
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var journalQuestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.warmBrown.opacity(0.5))
                Text("You Asked")
                    .font(.custom("BricolageGrotesque24pt-Medium", size: 12))
                    .foregroundStyle(Color.warmBrown.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.gray.opacity(0.08)))

            Text(String(journalQuestion.prefix(journalTextVisible)))
                .font(.custom("BricolageGrotesque72pt-Bold", size: 22))
                .foregroundStyle(Color.warmBrown)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Just now")
                .font(.custom("BricolageGrotesque24pt-Regular", size: 12))
                .foregroundStyle(Color.warmBrown.opacity(0.35))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var journalSkeletonBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonBar(width: 0.7)
            skeletonBar(width: 0.85)
            skeletonBar(width: 0.8)
            skeletonBar(width: 0.9)
            skeletonBar(width: 0.55)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Slide 3: Daily Goals

    private var mockupSlide3: some View {
        VStack(spacing: 14) {
            // Title
            Text("Today's Progress")
                .font(.custom("BricolageGrotesque24pt-SemiBold", size: 16))
                .foregroundStyle(Color.warmBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            // Goal rows
            goalRow(
                icon: "figure.walk",
                iconColor: .oliveGreen,
                label: "Steps",
                value: "7,500",
                target: "10,000",
                progress: stepsProgress
            )

            goalRow(
                icon: "drop.fill",
                iconColor: .blue,
                label: "Water",
                value: "6",
                target: "8 glasses",
                progress: waterProgress
            )

            goalRow(
                icon: "flame.fill",
                iconColor: .macroProt,
                label: "Calories",
                value: "1,840",
                target: "2,200",
                progress: caloriesProgress
            )

            goalRow(
                icon: "bed.double.fill",
                iconColor: .purple,
                label: "Sleep",
                value: "7.5h",
                target: "8h",
                progress: sleepProgress
            )
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
        )
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Goal Row

    private func goalRow(icon: String, iconColor: Color, label: String, value: String, target: String, progress: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.custom("BricolageGrotesque24pt-Medium", size: 13))
                        .foregroundStyle(Color.warmBrown)
                    Spacer()
                    Text(value)
                        .font(.custom("BricolageGrotesque24pt-SemiBold", size: 13))
                        .foregroundStyle(Color.warmBrown)
                    Text("/ \(target)")
                        .font(.custom("BricolageGrotesque24pt-Regular", size: 11))
                        .foregroundStyle(Color.warmBrown.opacity(0.4))
                }

                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(iconColor.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(iconColor)
                        .frame(height: 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: min(progress, 1.0), anchor: .leading)
                        .animation(.easeOut(duration: 1.0), value: progress)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Skeleton Bar

    private func skeletonBar(width: CGFloat) -> some View {
        GeometryReader { geo in
            let barWidth = geo.size.width * width * (skeletonGrown ? 1.0 : 0.0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.gray.opacity(0.12))
                .frame(width: barWidth, height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 10)
                        .offset(x: skeletonShimmer ? barWidth : -60)
                        .animation(
                            .linear(duration: 1.5).repeatForever(autoreverses: false),
                            value: skeletonShimmer
                        )
                        .clipped()
                )
                .animation(.easeOut(duration: 0.6).delay(Double.random(in: 0...0.3)), value: skeletonGrown)
        }
        .frame(height: 10)
    }

    // MARK: - Calorie Section

    private var calorieSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 160, height: 160)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 14)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        Color.gray.opacity(0.3),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(calorieCount)")
                        .font(.custom("BricolageGrotesque72pt-Bold", size: 28))
                        .foregroundStyle(Color.warmBrown)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.easeOut, value: calorieCount)
                    Text("cal")
                        .font(.custom("BricolageGrotesque24pt-Regular", size: 12))
                        .foregroundStyle(Color.warmBrown.opacity(0.45))
                }
            }
            .frame(width: 160, height: 160)
            .offset(x: -30)
            .overlay(alignment: .topTrailing) {
                macroBubble(value: "200", unit: "g", color: .macroProt, size: 60)
                    .offset(x: 10, y: bubblesFloat ? -8 : -2)
                    .scaleEffect(proteinIn ? 1 : 0.01)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: proteinIn)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: bubblesFloat)
            }
            .overlay(alignment: .trailing) {
                macroBubble(value: "95", unit: "g", color: .macroFat, size: 46)
                    .offset(x: 25, y: bubblesFloat ? 7 : 13)
                    .scaleEffect(fatIn ? 1 : 0.01)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: fatIn)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: bubblesFloat)
            }
            .overlay(alignment: .bottomTrailing) {
                macroBubble(value: "286", unit: "g", color: .macroCarb, size: 70)
                    .offset(x: -5, y: bubblesFloat ? 12 : 18)
                    .scaleEffect(carbIn ? 1 : 0.01)
                    .animation(.spring(response: 0.5, dampingFraction: 0.55), value: carbIn)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: bubblesFloat)
            }
            .frame(height: 190)

            HStack(spacing: 18) {
                legendDot(color: .macroProt, label: "Protein")
                legendDot(color: .macroCarb, label: "Carbs")
                legendDot(color: .macroFat, label: "Fat")
            }
            .opacity(legendIn ? 1 : 0)
            .offset(y: legendIn ? 0 : 6)
            .animation(.easeOut(duration: 0.4), value: legendIn)
        }
    }

    // MARK: - Helpers

    private func macroBubble(value: String, unit: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.3), radius: 6, y: 3)
            HStack(spacing: 1) {
                Text(value)
                    .font(.custom("BricolageGrotesque24pt-Bold", size: size * 0.28))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.custom("BricolageGrotesque24pt-Regular", size: size * 0.2))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.custom("BricolageGrotesque24pt-Medium", size: 12))
                .foregroundStyle(Color.warmBrown.opacity(0.6))
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: {}) {
            Text("Get Started")
                .font(.custom("BricolageGrotesque24pt-Bold", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    ZStack {
                        // Bottom darker layer — 3D raised effect
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.16, green: 0.19, blue: 0.10))
                            .offset(y: 3)

                        // Main fill with gradient
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.30, green: 0.35, blue: 0.22),
                                        Color.oliveGreen,
                                        Color(red: 0.20, green: 0.24, blue: 0.14)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Top highlight
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.12), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .shadow(color: Color.oliveGreen.opacity(ctaGlow ? 0.5 : 0.2), radius: ctaGlow ? 18 : 8, y: 6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(BounceButtonStyle())
        .offset(y: ctaIn ? 0 : 40)
        .opacity(ctaIn ? 1 : 0)
        .scaleEffect(ctaIn ? 1.0 : 0.92)
        .animation(.spring(response: 0.55, dampingFraction: 0.65), value: ctaIn)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: ctaGlow)
    }

    // MARK: - Sequence

    private func startSequence() {
        schedule(0.2) {
            headerIn = true
            logoBreathe = true
        }

        schedule(0.4) {
            impactMedium.impactOccurred()
            heroCardIn = true
        }

        schedule(0.8) {
            withAnimation(.easeOut(duration: 1.2)) { ringProgress = 0.75 }
        }

        schedule(0.9) { startCalorieCount() }

        schedule(1.1) {
            impactLight.impactOccurred()
            proteinIn = true
        }
        schedule(1.3) {
            impactLight.impactOccurred()
            fatIn = true
        }
        schedule(1.5) {
            impactLight.impactOccurred()
            carbIn = true
        }

        schedule(1.2) {
            cardBlur = 0
        }

        schedule(1.8) {
            legendIn = true
            bubblesFloat = true
        }

        schedule(2.4) {
            bottomBlur = 0
        }
        schedule(2.6) { headlineIn = true }

        schedule(3.0) {
            subtitleIn = true
            dotsIn = true
        }

        schedule(3.4) {
            impactMedium.impactOccurred()
            ctaIn = true
        }
        schedule(3.8) {
            ctaGlow = true
            startAutoSlide()
        }
    }

    // MARK: - Auto Slide

    private func startAutoSlide() {
        autoSlideTimer?.cancel()
        autoSlideTimer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage = (currentPage + 1) % 3
                }
            }
    }

    // MARK: - Calorie Counter

    private func startCalorieCount() {
        let target = 2800
        let steps = 40
        let perStep = target / steps
        var current = 0

        calorieTimer = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                current += perStep
                if current >= target {
                    calorieCount = target
                    calorieTimer?.cancel()
                } else {
                    calorieCount = current
                }
            }
    }

    // MARK: - Journal Typewriter

    private func startJournalTypewriter() {
        journalTimer?.cancel()
        journalTextVisible = 0
        journalTimer = Timer.publish(every: 0.04, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if journalTextVisible < journalQuestion.count {
                    journalTextVisible += 1
                } else {
                    journalTimer?.cancel()
                }
            }
    }

    // MARK: - Goal Counters

    private func startGoalCounters() {
        guard !goalsAnimated else { return }
        goalsAnimated = true

        withAnimation(.easeOut(duration: 1.0)) {
            stepsProgress = 0.75
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
            waterProgress = 0.75
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            caloriesProgress = 0.84
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            sleepProgress = 0.94
        }
    }

    private func schedule(_ delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

// MARK: - Custom FoodPal Logo

private struct FoodPalLogo: View {
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.oliveGreen.opacity(0.10))
                .frame(width: 54, height: 54)

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.40, blue: 0.22),
                            Color.oliveGreen,
                            Color(red: 0.16, green: 0.20, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .shadow(color: Color.oliveGreen.opacity(0.25), radius: 8, y: 3)

            // Inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 48, height: 48)

            // Custom icon: bowl + leaf + steam
            Canvas { context, size in
                let cx = size.width / 2
                let cy = size.height / 2

                // ── Bowl ──
                var bowl = Path()
                bowl.move(to: CGPoint(x: cx - 10, y: cy + 1))
                bowl.addQuadCurve(
                    to: CGPoint(x: cx + 10, y: cy + 1),
                    control: CGPoint(x: cx, y: cy + 13)
                )
                bowl.closeSubpath()
                context.stroke(bowl, with: .color(.white), lineWidth: 2.2)

                // Bowl rim
                var rim = Path()
                rim.move(to: CGPoint(x: cx - 12, y: cy + 1))
                rim.addLine(to: CGPoint(x: cx + 12, y: cy + 1))
                context.stroke(rim, with: .color(.white), lineWidth: 2.0)

                // ── Leaf ──
                var leaf = Path()
                leaf.move(to: CGPoint(x: cx + 2, y: cy - 1))
                leaf.addQuadCurve(
                    to: CGPoint(x: cx + 10, y: cy - 11),
                    control: CGPoint(x: cx + 12, y: cy - 3)
                )
                leaf.addQuadCurve(
                    to: CGPoint(x: cx + 2, y: cy - 1),
                    control: CGPoint(x: cx + 3, y: cy - 12)
                )
                context.fill(leaf, with: .color(.white.opacity(0.9)))

                // Leaf vein
                var vein = Path()
                vein.move(to: CGPoint(x: cx + 3, y: cy - 2))
                vein.addLine(to: CGPoint(x: cx + 8, y: cy - 9))
                context.stroke(vein, with: .color(.white.opacity(0.4)), lineWidth: 0.8)

                // ── Stem ──
                var stem = Path()
                stem.move(to: CGPoint(x: cx + 1, y: cy))
                stem.addQuadCurve(
                    to: CGPoint(x: cx - 2, y: cy - 8),
                    control: CGPoint(x: cx - 3, y: cy - 3)
                )
                context.stroke(stem, with: .color(.white.opacity(0.8)), lineWidth: 1.5)

                // ── Steam wisps ──
                let steamColor = Color.white.opacity(0.5)

                var steam1 = Path()
                steam1.move(to: CGPoint(x: cx - 5, y: cy - 2))
                steam1.addQuadCurve(
                    to: CGPoint(x: cx - 6, y: cy - 9),
                    control: CGPoint(x: cx - 8, y: cy - 5)
                )
                context.stroke(steam1, with: .color(steamColor), lineWidth: 1.2)

                var steam2 = Path()
                steam2.move(to: CGPoint(x: cx - 1, y: cy - 1))
                steam2.addQuadCurve(
                    to: CGPoint(x: cx - 2, y: cy - 10),
                    control: CGPoint(x: cx + 1, y: cy - 5)
                )
                context.stroke(steam2, with: .color(steamColor), lineWidth: 1.2)
            }
            .frame(width: 36, height: 36)
        }
    }
}

// MARK: - Chip Transition Modifier

private struct ChipTransitionModifier: ViewModifier {
    let offset: CGFloat
    let blur: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .blur(radius: blur)
            .scaleEffect(scale)
            .opacity(blur > 0 ? 0 : 1)
    }
}

// MARK: - Bounce Button Style

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    FoodPalWelcomeV2View()
}
