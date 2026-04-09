//
//  StretchyTextView.swift
//  Motion

import SwiftUI

// MARK: - Spring animator (DisplayLink-driven smooth interpolation)

@Observable
final class StretchAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    var targetStrength: Double = 0.0
    var currentStrength: Double = 0.0

    private var displayLink: CADisplayLink?

    // Heavier damping when dragging, springy overshoot on release
    private var isDragging = false
    private let dragSmoothing: Double = 0.18
    private let releaseSmoothing: Double = 0.06
    private let releaseDamping: Double = 0.92
    private var velocity: CGPoint = .zero

    func beginDrag() { isDragging = true }

    func endDrag() {
        isDragging = false
        targetStrength = 0.0
        targetPos = currentPos // snap target so spring pulls back
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
            // Smooth chase while dragging
            currentPos.x += (targetPos.x - currentPos.x) * dragSmoothing
            currentPos.y += (targetPos.y - currentPos.y) * dragSmoothing
            currentStrength += (targetStrength - currentStrength) * dragSmoothing
        } else {
            // Spring back with overshoot on release
            let dx = targetPos.x - currentPos.x
            let dy = targetPos.y - currentPos.y
            velocity.x = (velocity.x + dx * releaseSmoothing) * releaseDamping
            velocity.y = (velocity.y + dy * releaseSmoothing) * releaseDamping
            currentPos.x += velocity.x
            currentPos.y += velocity.y
            currentStrength += (targetStrength - currentStrength) * 0.1
        }
    }
}

// MARK: - View

struct StretchyTextView: View {

    @State private var animator = StretchAnimator()
    @State private var dragOrigin: CGPoint = .zero

    private let radius: Double = 120.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            stretchyText("Stretchy", size: 80, weight: .black)

         

            // Hint — bottom
            Text("drag anywhere to stretch")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }

    private func stretchyText(_ text: String, size: CGFloat, weight: Font.Weight) -> some View {
        Text(text)
            .font(.custom("BricolageGrotesque72pt-ExtraBold", size: size))
            .foregroundStyle(.black)
            .padding(40)
            .distortionEffect(
                ShaderLibrary.stretchEffect(
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
                        // Strength based on drag distance
                        let dist = hypot(
                            value.location.x - dragOrigin.x,
                            value.location.y - dragOrigin.y
                        )
                        animator.targetStrength = min(dist / 150.0, 0.8)
                    }
                    .onEnded { _ in
                        animator.endDrag()
                    }
            )
    }
}

#Preview {
    StretchyTextView()
}
