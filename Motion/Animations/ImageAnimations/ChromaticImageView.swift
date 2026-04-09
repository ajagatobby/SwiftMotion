import SwiftUI

@Observable
final class ChromaticAnimator {
    var targetOffset: CGPoint = .zero
    var currentOffset: CGPoint = .zero
    private var displayLink: CADisplayLink?
    private var velocity: CGPoint = .zero
    private var isDragging = false

    func beginDrag() { isDragging = true; velocity = .zero }
    func endDrag() { isDragging = false; targetOffset = .zero }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() { displayLink?.invalidate(); displayLink = nil }

    @objc private func tick() {
        if isDragging {
            currentOffset.x += (targetOffset.x - currentOffset.x) * 0.2
            currentOffset.y += (targetOffset.y - currentOffset.y) * 0.2
        } else {
            velocity.x = (velocity.x + (targetOffset.x - currentOffset.x) * 0.08) * 0.88
            velocity.y = (velocity.y + (targetOffset.y - currentOffset.y) * 0.08) * 0.88
            currentOffset.x += velocity.x
            currentOffset.y += velocity.y
        }
    }
}

struct ChromaticImageView: View {
    @State private var animator = ChromaticAnimator()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                Image("eagle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320)
                    .padding(40)
                    .layerEffect(
                        ShaderLibrary.chromaticEffect(
                            .float2(
                                animator.currentOffset.x * 0.15,
                                animator.currentOffset.y * 0.15
                            ),
                            .float(1.0)
                        ),
                        maxSampleOffset: CGSize(width: 30, height: 30)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                animator.targetOffset = CGPoint(
                                    x: value.translation.width,
                                    y: value.translation.height
                                )
                            }
                            .onEnded { _ in
                                animator.endDrag()
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                animator.beginDrag()
                            }
                    )
            }

            Text("tap/drag to split")
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
    ChromaticImageView()
}
