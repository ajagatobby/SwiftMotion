import SwiftUI

@Observable
final class MorphAnimator {
    var targetPos: CGPoint = .zero
    var currentPos: CGPoint = .zero
    var targetStrength: Double = 0.0
    var currentStrength: Double = 0.0
    private var displayLink: CADisplayLink?
    private var velocity: CGPoint = .zero
    private var isDragging = false

    func beginDrag() { isDragging = true; velocity = .zero }
    func endDrag() { isDragging = false; targetStrength = 0.0 }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() { displayLink?.invalidate(); displayLink = nil }

    @objc private func tick() {
        if isDragging {
            currentPos.x += (targetPos.x - currentPos.x) * 0.18
            currentPos.y += (targetPos.y - currentPos.y) * 0.18
            currentStrength += (targetStrength - currentStrength) * 0.15
        } else {
            velocity.x = (velocity.x + (targetPos.x - currentPos.x) * 0.06) * 0.9
            velocity.y = (velocity.y + (targetPos.y - currentPos.y) * 0.06) * 0.9
            currentPos.x += velocity.x
            currentPos.y += velocity.y
            currentStrength += (targetStrength - currentStrength) * 0.1
        }
    }
}

struct MorphImageView: View {
    @State private var animator = MorphAnimator()
    @State private var imageSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(40)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            imageSize = geo.size
                        }
                    }
                )
                .distortionEffect(
                    ShaderLibrary.morphEffect(
                        .float2(animator.currentPos),
                        .float(animator.currentStrength),
                        .float(120)
                    ),
                    maxSampleOffset: CGSize(width: 100, height: 100)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            animator.targetPos = value.location
                            animator.targetStrength = 1.0
                            animator.beginDrag()
                        }
                        .onEnded { _ in
                            animator.endDrag()
                        }
                )

            Text("drag to warp")
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
    MorphImageView()
}
