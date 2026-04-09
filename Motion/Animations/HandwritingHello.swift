//
//  HandwritingHello.swift
//  Motion
//
//  Created by Abdulbasit Ajaga on 01/04/2026.

import SwiftUI

// MARK: - Hello sticker with script font and writing reveal

struct HelloStickerContent: View {
    var progress: CGFloat

    var body: some View {
        Text("hello")
            .font(.custom("Snell Roundhand", size: 58).bold())
            .foregroundStyle(.black)
            .mask(
                GeometryReader { geo in
                    let revealWidth = geo.size.width * progress
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: revealWidth)
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 14)
                        Spacer(minLength: 0)
                    }
                }
            )
            .frame(width: 200, height: 70)
    }
}

// MARK: - Draggable sticker wrapper with lift, shadow, haptics

struct DraggableStickerModifier: ViewModifier {
    @State private var position: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var isDragging = false
    @State private var velocity: CGSize = .zero
    @State private var smoothVelocity: CGSize = .zero

    // Tilt based on smoothed velocity — lag gives organic inertia feel
    private var tiltX: Double {
        Double(smoothVelocity.height) * 0.008
    }
    private var tiltY: Double {
        Double(-smoothVelocity.width) * 0.008
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .rotation3DEffect(
                .degrees(isDragging ? Double(smoothVelocity.width) * 0.02 : 0),
                axis: (x: 0, y: 0, z: 1)
            )
            .rotation3DEffect(
                .degrees(tiltX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(tiltY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .shadow(
                color: .black.opacity(isDragging ? 0.16 : 0.08),
                radius: isDragging ? 20 : 6,
                x: isDragging ? CGFloat(smoothVelocity.width) * -0.01 : 0,
                y: isDragging ? 14 : 3
            )
            // Position tracks finger directly — zero animation lag
            .offset(position)
            .zIndex(isDragging ? 100 : 0)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                isDragging = true
                            }
                            dragStart = position
                        }
                        // Direct 1:1 tracking — no spring on position
                        position = CGSize(
                            width: dragStart.width + value.translation.width,
                            height: dragStart.height + value.translation.height
                        )
                        velocity = CGSize(
                            width: value.velocity.width,
                            height: value.velocity.height
                        )
                        // Smooth velocity for tilt/rotation (low-pass filter)
                        smoothVelocity = CGSize(
                            width: smoothVelocity.width * 0.7 + value.velocity.width * 0.3,
                            height: smoothVelocity.height * 0.7 + value.velocity.height * 0.3
                        )
                    }
                    .onEnded { value in
                        // Momentum coast — flick to predicted position
                        let momentumScale: CGFloat = 0.08
                        let targetPosition = CGSize(
                            width: position.width + value.velocity.width * momentumScale,
                            height: position.height + value.velocity.height * momentumScale
                        )
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                            position = targetPosition
                            isDragging = false
                            smoothVelocity = .zero
                        }
                    }
            )
            // Only animate the visual properties, not position
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: smoothVelocity)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDragging)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.35), trigger: isDragging)
    }
}

extension View {
    func draggableSticker() -> some View {
        modifier(DraggableStickerModifier())
    }
}

// MARK: - Icon sticker with entrance + drag

struct IconStickerView: View {
    let icon: AppIcon
    let size: CGFloat
    let color: Color
    let rotation: Double
    let delay: Double
    @ObservedObject var motion: MotionManager
    @State private var appeared = false

    var body: some View {
        GlossyStickerWrap(rotation: appeared ? rotation : rotation - 30, motion: motion) {
            AppIconView(icon: icon, size: size, color: color)
        }
        .scaleEffect(appeared ? 1 : 0.01)
        .opacity(appeared ? 1 : 0)
        .draggableSticker()
        .onAppear {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.55)
                .delay(delay)
            ) {
                appeared = true
            }
        }
    }
}

// MARK: - Main view

struct HandwritingHello: View {
    @StateObject private var motion = MotionManager()
    @State private var strokeProgress: CGFloat = 0
    @State private var showStickers = false
    @State private var helloAppeared = false

    private let stickers: [(icon: AppIcon, color: Color, x: CGFloat, y: CGFloat, size: CGFloat, rotation: Double, delay: Double)] = [
        (.swiftUI,  .blue,   0.62, 0.08, 104, -8,   0.2),
        (.xcode,    .blue,   0.14, 0.15, 100, 10,   0.35),
        (.python,   .blue,   0.85, 0.30, 100, -6,   0.5),
        (.github,   .black,  0.12, 0.55, 96,  -12,  0.65),
        (.figma,    .purple, 0.50, 0.68, 92,  3,    0.8),
        (.react,    .cyan,   0.85, 0.62, 96,  -5,   0.95),
        (.code,     .purple, 0.14, 0.78, 92,  8,    1.1),
        (.firebase, .orange, 0.75, 0.82, 88,  -7,   1.25),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()

                // "hello" text sticker
                GlossyStickerWrap(rotation: -6, motion: motion) {
                    HelloStickerContent(progress: strokeProgress)
                }
                .scaleEffect(helloAppeared ? 1 : 0.01)
                .opacity(helloAppeared ? 1 : 0)
                .draggableSticker()
                .position(
                    x: geo.size.width * 0.45,
                    y: geo.size.height * 0.40
                )

                // Icon stickers
                if showStickers {
                    ForEach(Array(stickers.enumerated()), id: \.offset) { _, sticker in
                        IconStickerView(
                            icon: sticker.icon,
                            size: sticker.size,
                            color: sticker.color,
                            rotation: sticker.rotation,
                            delay: sticker.delay,
                            motion: motion
                        )
                        .position(
                            x: geo.size.width * sticker.x,
                            y: geo.size.height * sticker.y
                        )
                    }
                }
            }
        }
        .onAppear {
            // Hello sticker drops in first
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
                helloAppeared = true
            }
            // Writing reveal starts after sticker lands
            withAnimation(
                .easeOut(duration: 2.0)
                .delay(0.9)
            ) {
                strokeProgress = 1.0
            }
            // Icon stickers cascade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showStickers = true
            }
        }
    }
}

#Preview {
    HandwritingHello()
}
