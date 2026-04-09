
import SwiftUI
import AudioToolbox

struct LiquidFillButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var fillProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var completed = false
    @State private var holdTimer: Timer?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.15))

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: geo.size.width * fillProgress)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 8) {
                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(completed ? "Done!" : title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(fillProgress > 0.5 ? .white : color)
        }
        .frame(height: 54)
        .scaleEffect(isHolding ? 0.97 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHolding)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !completed else { return }
                    if !isHolding {
                        isHolding = true
                        AudioServicesPlaySystemSound(1104)
                        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in
                            withAnimation(.linear(duration: 1.0 / 60)) {
                                fillProgress = min(1, fillProgress + 1.0 / 60 / 1.5)
                            }
                            if fillProgress >= 1 {
                                holdTimer?.invalidate()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    completed = true
                                    isHolding = false
                                }
                                AudioServicesPlaySystemSound(1001)
                                action()
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isHolding = false
                    holdTimer?.invalidate()
                    if !completed {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            fillProgress = 0
                        }
                    }
                }
        )
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: completed)
        .onTapGesture {
            if completed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    completed = false
                    fillProgress = 0
                }
            }
        }
    }
}
