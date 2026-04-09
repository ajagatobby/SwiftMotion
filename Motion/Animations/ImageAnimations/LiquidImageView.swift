//
//  LiquidImageView.swift
//  Motion

import SwiftUI
import Combine

@Observable
final class LiquidImageAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    var targetActive: Double = 0.0
    var currentActive: Double = 0.0

    private var displayLink: CADisplayLink?

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
        currentPos.x += (targetPos.x - currentPos.x) * 0.12
        currentPos.y += (targetPos.y - currentPos.y) * 0.12
        currentActive += (targetActive - currentActive) * 0.08
    }
}

struct LiquidImageView: View {

    @State private var time: Double = 0.0
    @State private var intensity: Double = 0.0
    @State private var isActive = false
    @State private var animator = LiquidImageAnimator()

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(60)
                .distortionEffect(
                    ShaderLibrary.liquidImageEffect(
                        .float2(440, 540),
                        .float(time),
                        .float(intensity),
                        .float(animator.currentPos.x),
                        .float(animator.currentPos.y),
                        .float(animator.currentActive)
                    ),
                    maxSampleOffset: CGSize(width: 80, height: 80)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture {
                    isActive.toggle()
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        intensity = isActive ? 1.0 : 0.0
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            animator.targetPos = value.location
                            animator.targetActive = 1.0
                        }
                        .onEnded { _ in
                            animator.targetActive = 0.0
                        }
                )
                .onReceive(timer) { _ in
                    time += 1.0 / 60.0
                }

            Text(isActive ? "tap to solidify · drag to swirl" : "tap to melt")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: isActive)
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

#Preview {
    LiquidImageView()
}
