//
//  MagnetTextView.swift
//  Motion

import SwiftUI

// MARK: - DisplayLink-driven smooth animator

@Observable
final class MagnetAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    var targetStrength: Double = 0.0
    var currentStrength: Double = 0.0

    private var displayLink: CADisplayLink?
    private var velocity: CGPoint = .zero
    private var isDragging = false

    func beginDrag() { isDragging = true }

    func endDrag() {
        isDragging = false
        targetStrength = 0.0
    }

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
        if isDragging {
            currentPos.x += (targetPos.x - currentPos.x) * 0.15
            currentPos.y += (targetPos.y - currentPos.y) * 0.15
            currentStrength += (targetStrength - currentStrength) * 0.15
        } else {
            let dx = targetPos.x - currentPos.x
            let dy = targetPos.y - currentPos.y
            velocity.x = (velocity.x + dx * 0.06) * 0.92
            velocity.y = (velocity.y + dy * 0.06) * 0.92
            currentPos.x += velocity.x
            currentPos.y += velocity.y
            currentStrength += (targetStrength - currentStrength) * 0.1
        }
    }
}

// MARK: - View

struct MagnetTextView: View {

    @State private var animator = MagnetAnimator()
    @State private var dragOrigin: CGPoint = .zero

    private let radius: Double = 150.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Text("Magnet")
                .font(.custom("BricolageGrotesque72pt-ExtraBold", size: 80))
                .foregroundStyle(.black)
                .padding(60)
                .distortionEffect(
                    ShaderLibrary.magnetEffect(
                        .float2(animator.currentPos),
                        .float(animator.currentStrength),
                        .float(radius)
                    ),
                    maxSampleOffset: CGSize(width: 200, height: 200)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if animator.targetStrength == 0.0 {
                                dragOrigin = value.startLocation
                                animator.currentPos = value.startLocation
                                animator.beginDrag()
                            }
                            animator.targetPos = value.location
                            let dist = hypot(
                                value.location.x - dragOrigin.x,
                                value.location.y - dragOrigin.y
                            )
                            animator.targetStrength = min(dist / 120.0, 1.0)
                        }
                        .onEnded { _ in
                            animator.endDrag()
                        }
                )

            Text("drag to attract")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

#Preview {
    MagnetTextView()
}
