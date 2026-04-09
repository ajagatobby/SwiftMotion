//
//  HoldToFillButton.swift
//  Motion
//
//  Created by Abdulbasit Ajaga on 01/04/2026.


import SwiftUI
import AudioToolbox

struct ShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress
        let decay = exp(-2.5 * t)

        let primary = sin(2 * .pi * 6 * t)
        let secondary = sin(2 * .pi * 10 * t) * 0.3

        let wave = primary + secondary
        let offset = 18 * decay * wave
        let rotation = (3.5 * .pi / 180) * decay * primary

        let verticalOffset = 4 * decay * sin(2 * .pi * 8 * t + .pi / 4)

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: size.width / 2, y: size.height / 2)
        transform = transform.rotated(by: rotation)
        transform = transform.translatedBy(x: -size.width / 2 + offset, y: -size.height / 2 + verticalOffset)

        return ProjectionTransform(transform)
    }
}

// MARK: - Button content (shared between both versions)

struct HoldToFillButtonContent: View {
    var fillProgress: CGFloat

    var body: some View {
        Text("Press")
            .font(.title2.bold())
            .fontDesign(.rounded)
            .foregroundStyle(
                Color(
                    red: 0.0 + fillProgress * 1.0,
                    green: 0.478 + fillProgress * (1.0 - 0.478),
                    blue: 1.0
                )
            )
            .frame(width: 280, height: 65)
            .background {
                Capsule()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geo.size.width * fillProgress)
                        }
                    }
                    .clipShape(Capsule())
            }
    }
}

// MARK: - Glossy capsule wrapper (with Metal shader reflection)

struct GlossyCapsuleWrap<Content: View>: View {
    let content: Content
    @ObservedObject var motion: MotionManager

    init(motion: MotionManager, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.motion = motion
    }

    var body: some View {
        content
            .overlay(
                Capsule()
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
            .clipShape(Capsule())
            .glossyReflection(motion: motion)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Plain capsule wrapper (no shader, no reflection)

struct PlainCapsuleWrap<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .overlay(
                Capsule()
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Shared hold-to-fill logic

private struct HoldToFillCore<Wrapper: View>: View {
    let wrapper: (HoldToFillButtonContent) -> Wrapper
    let label: String

    @State private var fillProgress: CGFloat = 0
    @State private var isPressed = false
    @State private var isCompleted = false
    @State private var shakeProgress: CGFloat = 0
    @State private var isLocked = false
    @State private var breathScale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0
    @State private var isShaking = false
    @State private var holdTimer: Timer?
    @State private var holdStart: Date?

    private let fillDuration: Double = 1.5
    private let timerInterval: Double = 1.0 / 60.0

    var body: some View {
        VStack(spacing: 8) {
            wrapper(HoldToFillButtonContent(fillProgress: fillProgress))
                .modifier(ShakeEffect(progress: shakeProgress))
                .scaleEffect(isPressed ? 0.96 : breathScale)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressed, !isLocked else { return }
                            isPressed = true
                            isCompleted = false
                            AudioServicesPlaySystemSound(1104)
                            startFilling()
                        }
                        .onEnded { _ in
                            guard !isLocked else { return }
                            stopFilling()
                            if fillProgress >= 1.0 {
                                isCompleted = true
                                isLocked = true
                                isPressed = false
                                AudioServicesPlaySystemSound(1075)
                                holdThenShake()
                            } else {
                                AudioServicesPlaySystemSound(1070)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    fillProgress = 0
                                    glowOpacity = 0
                                }
                                isPressed = false
                            }
                        }
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPressed)
                .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
                .sensoryFeedback(.error, trigger: isShaking)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { startBreathing() }
    }

    private func startFilling() {
        holdStart = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            guard let start = holdStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(elapsed / fillDuration, 1.0)

            DispatchQueue.main.async {
                fillProgress = progress
                glowOpacity = progress * 0.5

                if progress >= 1.0 {
                    stopFilling()
                    isCompleted = true
                    isLocked = true
                    isPressed = false
                    AudioServicesPlaySystemSound(1075)
                    holdThenShake()
                }
            }
        }
    }

    private func stopFilling() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdStart = nil
    }

    private func startBreathing() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: true)
        ) {
            breathScale = 1.02
        }
    }

    private func holdThenShake() {
        withAnimation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true)) {
            glowOpacity = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isShaking = true
            AudioServicesPlaySystemSound(1521)
            withAnimation(.easeIn(duration: 0.15)) {
                breathScale = 0.94
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                AudioServicesPlaySystemSound(1005)
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    breathScale = 1.0
                }
                withAnimation(.linear(duration: 1.8)) {
                    shakeProgress = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                    isShaking = false
                    AudioServicesPlaySystemSound(1016)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        fillProgress = 0
                        glowOpacity = 0
                    }
                    shakeProgress = 0
                    isLocked = false
                    isCompleted = false
                }
            }
        }
    }
}

// MARK: - Version 1: With Metal reflective shader

struct HoldToFillButton: View {
    @StateObject private var motion = MotionManager()

    var body: some View {
        HoldToFillCore(
            wrapper: { content in
                GlossyCapsuleWrap(motion: motion) { content }
            },
            label: "Reflective Shader"
        )
    }
}

// MARK: - Version 2: Plain (no shader, no reflection)

struct HoldToFillButtonPlain: View {
    var body: some View {
        HoldToFillCore(
            wrapper: { content in
                PlainCapsuleWrap { content }
            },
            label: "Plain"
        )
    }
}

#Preview("Both Versions") {
    VStack(spacing: 40) {
        HoldToFillButton()
        HoldToFillButtonPlain()
    }
}
