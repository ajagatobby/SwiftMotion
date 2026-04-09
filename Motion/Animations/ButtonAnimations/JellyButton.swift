
import SwiftUI
import AudioToolbox

struct JellyButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1
    @State private var isHolding = false
    @State private var wobbleTimer: Timer?
    @State private var wobblePhase = 0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.gradient)
            )
            .scaleEffect(x: scaleX, y: scaleY)
            .offset(dragOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isHolding {
                            isHolding = true
                            AudioServicesPlaySystemSound(1104)
                            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                                scaleX = 1.08; scaleY = 0.88
                            }
                            startWobble()
                        }

                        // Stretch toward drag
                        let tx = value.translation.width
                        let ty = value.translation.height
                        withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.6)) {
                            dragOffset = CGSize(
                                width: tx * 0.25 / (1 + abs(tx) / 120),
                                height: ty * 0.25 / (1 + abs(ty) / 80)
                            )
                        }

                        let pullH = abs(tx) / 200
                        let pullV = abs(ty) / 150
                        if abs(tx) > abs(ty) {
                            withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.5)) {
                                scaleX = 1.0 + min(pullH, 0.25)
                                scaleY = 1.0 / sqrt(1.0 + min(pullH, 0.25))
                            }
                        } else {
                            withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.5)) {
                                scaleY = 1.0 + min(pullV, 0.2)
                                scaleX = 1.0 / sqrt(1.0 + min(pullV, 0.2))
                            }
                        }
                    }
                    .onEnded { _ in
                        isHolding = false
                        wobbleTimer?.invalidate()
                        wobbleTimer = nil

                        // Jelly snap back
                        withAnimation(.spring(response: 0.12, dampingFraction: 0.3)) {
                            scaleX = 0.9; scaleY = 1.14; dragOffset = .zero
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) {
                                scaleX = 1.06; scaleY = 0.95
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                scaleX = 1; scaleY = 1
                            }
                            action()
                        }
                    }
            )
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: isHolding)
    }

    private func startWobble() {
        wobblePhase = 0
        wobbleTimer?.invalidate()
        wobbleTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            guard isHolding else { return }
            wobblePhase += 1
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                scaleX = wobblePhase % 2 == 0 ? 1.06 : 0.96
                scaleY = wobblePhase % 2 == 0 ? 0.95 : 1.04
            }
        }
    }
}
