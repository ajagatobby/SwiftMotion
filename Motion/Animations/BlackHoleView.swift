//
//  BlackHoleView.swift
//  Motion

import SwiftUI
import Combine

// MARK: - Smooth touch animator

@Observable
final class BlackHoleAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    private var displayLink: CADisplayLink?
    private var velocity: CGPoint = .zero
    private(set) var isDragging = false

    func beginDrag() { isDragging = true; velocity = .zero }
    func endDrag() { isDragging = false }

    func start(center: CGPoint) {
        targetPos = center
        currentPos = center
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
            currentPos.x += (targetPos.x - currentPos.x) * 0.08
            currentPos.y += (targetPos.y - currentPos.y) * 0.08
        } else {
            // Gentle drift back toward target with damping
            velocity.x = (velocity.x + (targetPos.x - currentPos.x) * 0.02) * 0.95
            velocity.y = (velocity.y + (targetPos.y - currentPos.y) * 0.02) * 0.95
            currentPos.x += velocity.x
            currentPos.y += velocity.y
        }
    }
}

// MARK: - View

struct BlackHoleView: View {

    @State private var animator = BlackHoleAnimator()
    @State private var time: Double = 0.0
    @State private var mass: Double = 1.0
    @State private var viewSize: CGSize = .zero

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Full-screen shader canvas
            Rectangle()
                .fill(.black)
                .ignoresSafeArea()
                .colorEffect(
                    ShaderLibrary.blackHoleEffect(
                        .float2(viewSize.width, viewSize.height),
                        .float2(animator.currentPos),
                        .float(time),
                        .float(mass)
                    )
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                viewSize = geo.size
                                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                animator.start(center: center)
                            }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !animator.isDragging {
                                animator.beginDrag()
                            }
                            animator.targetPos = value.location
                        }
                        .onEnded { _ in
                            animator.endDrag()
                        }
                )
                .onReceive(timer) { _ in
                    time += 1.0 / 60.0
                }

            // Controls overlay
            VStack {
                // Title tag
                HStack(spacing: 6) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)

                    Text("BLACK HOLE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.5)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .padding(.top, 60)

                Spacer()

                // Mass slider
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))

                    Slider(value: $mass, in: 0.3...2.5)
                        .tint(.orange)

                    Image(systemName: "circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 40)

                Text("drag to move · slider for mass")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 50)
            }
        }
        .onDisappear { animator.stop() }
    }
}

#Preview {
    BlackHoleView()
}
