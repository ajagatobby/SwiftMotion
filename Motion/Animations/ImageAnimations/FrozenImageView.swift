//
//  FrozenImageView.swift
//  Motion
//
//  Freeze Frame — drag to freeze, frost grows from touch point.

import SwiftUI
import Combine

@Observable
final class FreezeAnimator {
    var targetRadius: Double = 0
    var currentRadius: Double = 0
    var intensity: Double = 0
    var touchPos: CGPoint = .zero

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
        currentRadius += (targetRadius - currentRadius) * 0.025
        let targetInt: Double = targetRadius > 0 ? 1.0 : 0.0
        intensity += (targetInt - intensity) * 0.05
    }

    func freeze(at point: CGPoint) {
        touchPos = point
        targetRadius = 500
    }

    func thaw() {
        targetRadius = 0
        currentRadius = 0
        intensity = 0
    }
}

struct FrozenImageView: View {

    @State private var animator = FreezeAnimator()
    @State private var time: Double = 0
    @State private var isFrozen = false
    @State private var imageSize: CGSize = .zero

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(40)
                .overlay(
                    GeometryReader { geo in
                        Color.clear.onAppear { imageSize = geo.size }
                    }
                )
                .layerEffect(
                    ShaderLibrary.frozenEffect(
                        .float2(imageSize.width, imageSize.height),
                        .float(animator.touchPos.x),
                        .float(animator.touchPos.y),
                        .float(animator.currentRadius),
                        .float(time),
                        .float(animator.intensity)
                    ),
                    maxSampleOffset: CGSize(width: 8, height: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: isFrozen ? Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.3) : .clear,
                        radius: 20, y: 5)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isFrozen {
                                isFrozen = true
                                animator.freeze(at: value.startLocation)
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if isFrozen {
                                isFrozen = false
                                animator.thaw()
                            }
                        }
                )

            Text(isFrozen ? "tap to thaw" : "tap to freeze")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
                .contentTransition(.numericText())
                .animation(.easeInOut, value: isFrozen)
        }
        .onReceive(timer) { _ in
            time += 1.0 / 60.0
        }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

#Preview {
    FrozenImageView()
}
