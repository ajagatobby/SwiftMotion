//
//  GlossySticker.swift
//  Motion
//
//  Created by Abdulbasit Ajaga on 01/04/2026.

import SwiftUI
import Combine
import CoreMotion

// MARK: - Gyroscope-driven motion manager

class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    /// Low-pass filter factor. Lower = smoother but laggier.
    /// 0.15 gives a premium, fluid feel without perceptible delay.
    private let smoothing: Double = 0.15

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion, let self = self else { return }
            // Low-pass filter: smoothed = previous * (1-α) + new * α
            self.pitch = self.pitch * (1.0 - self.smoothing) + motion.attitude.pitch * self.smoothing
            self.roll  = self.roll  * (1.0 - self.smoothing) + motion.attitude.roll  * self.smoothing
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Metal glossy reflection modifier
// Replaces the old Canvas-based GlossyReflectionOverlay with a GPU-accelerated
// Metal shader (.layerEffect) for smoother, more realistic specular reflections.
// Requires iOS 17+. The shader lives in GlossySticker.metal.

struct GlossyReflectionModifier: ViewModifier {
    @ObservedObject var motion: MotionManager

    func body(content: Content) -> some View {
        content
            .visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.glossyReflection(
                        .float2(proxy.size.width, proxy.size.height),
                        .float2(motion.roll, motion.pitch)
                    ),
                    maxSampleOffset: CGSize(width: 2, height: 2)
                )
            }
    }
}

extension View {
    func glossyReflection(motion: MotionManager) -> some View {
        modifier(GlossyReflectionModifier(motion: motion))
    }
}

// MARK: - Glossy sticker wrapper

struct GlossyStickerWrap<Content: View>: View {
    let content: Content
    let rotation: Double
    @ObservedObject var motion: MotionManager

    init(
        rotation: Double = 0,
        motion: MotionManager,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.rotation = rotation
        self.motion = motion
    }

    var body: some View {
        content
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glossyReflection(motion: motion)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            .rotationEffect(.degrees(rotation))
    }
}
