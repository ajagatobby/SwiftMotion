//
//  DitherView.swift
//  Motion

import SwiftUI

// Smoothly chases a target CGPoint using spring-like interpolation each frame
@Observable
final class RevealAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    var targetActive: Double = 0.0
    var currentActive: Double = 0.0
    var targetRadius: Double = 70.0
    var currentRadius: Double = 0.0

    private var displayLink: CADisplayLink?
    private let posSmoothing: Double = 0.15
    private let activeSmoothing: Double = 0.08

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        currentPos.x += (targetPos.x - currentPos.x) * posSmoothing
        currentPos.y += (targetPos.y - currentPos.y) * posSmoothing
        currentActive += (targetActive - currentActive) * activeSmoothing
        currentRadius += (targetRadius - currentRadius) * activeSmoothing
    }
}

struct DitherView: View {

    @State private var ditherAmount: Double = 0.0
    @State private var pixelScale: Double = 3.0
    @State private var animator = RevealAnimator()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Eagle image — centered
            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 340)
                .colorEffect(
                    ShaderLibrary.ditherEffect(
                        .float(ditherAmount),
                        .float(pixelScale),
                        .float(animator.currentPos.x),
                        .float(animator.currentPos.y),
                        .float(animator.currentActive),
                        .float(animator.currentRadius)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            animator.targetPos = value.location
                            animator.targetActive = 1.0
                            animator.targetRadius = 70.0
                        }
                        .onEnded { _ in
                            animator.targetActive = 0.0
                            animator.targetRadius = 0.0
                        }
                )
                .onAppear { animator.start() }
                .onDisappear { animator.stop() }

            // Controls — bottom
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .foregroundStyle(.black.opacity(0.4))
                        .font(.system(size: 13))

                    Slider(value: $ditherAmount, in: 0...1)
                        .tint(.black)

                    Image(systemName: "circle.grid.3x3.fill")
                        .foregroundStyle(.black.opacity(0.4))
                        .font(.system(size: 13))
                }

                HStack(spacing: 12) {
                    Text("1px")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))

                    Slider(value: $pixelScale, in: 1...8)
                        .tint(.black)

                    Text("8px")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))
                }
            }
            .padding(.horizontal, 32)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 50)

            // Label — top
            HStack(spacing: 6) {
                Circle()
                    .fill(.black)
                    .frame(width: 6, height: 6)

                Text("BAYER DITHER")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.85))
                    .tracking(1.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.06))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
        }
    }
}

#Preview {
    DitherView()
}
