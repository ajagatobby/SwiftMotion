
import SwiftUI
import AudioToolbox

struct ElasticPillButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var toggled = false
    @State private var scaleX: CGFloat = 1
    @State private var scaleY: CGFloat = 1
    @State private var isHolding = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toggled ? "bell.slash.fill" : icon)
                .font(.system(size: 16, weight: .bold))
                .contentTransition(.symbolEffect(.replace.downUp))

            Text(toggled ? "Unsubscribe" : title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .frame(height: 50)
        .background(
            Capsule()
                .fill(toggled ? .gray : color)
                .shadow(color: (toggled ? .gray : color).opacity(0.4), radius: 8, y: 4)
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
                            scaleX = 1.1; scaleY = 0.88
                        }
                    }

                    let tx = value.translation.width
                    let ty = value.translation.height
                    withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.5)) {
                        dragOffset = CGSize(
                            width: tx * 0.2 / (1 + abs(tx) / 100),
                            height: ty * 0.2 / (1 + abs(ty) / 80)
                        )
                    }

                    let pull = sqrt(tx * tx + ty * ty) / 150
                    let stretch = 1.0 + min(CGFloat(pull), 0.2)
                    let squeeze = 1.0 / sqrt(stretch)
                    if abs(tx) > abs(ty) {
                        withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.5)) {
                            scaleX = stretch; scaleY = squeeze
                        }
                    } else {
                        withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.5)) {
                            scaleY = stretch; scaleX = squeeze
                        }
                    }
                }
                .onEnded { _ in
                    isHolding = false
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                        scaleX = 0.88; scaleY = 1.12; dragOffset = .zero
                        toggled.toggle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                            scaleX = 1; scaleY = 1
                        }
                        action()
                    }
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: toggled)
    }
}
