
import SwiftUI
import AudioToolbox

struct MagneticButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(isPressed ? 0.3 : 0), .clear],
                                center: UnitPoint(
                                    x: 0.5 + offset.width / 300,
                                    y: 0.5 + offset.height / 200
                                ),
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .offset(offset)
            .scaleEffect(isPressed ? 1.03 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed { AudioServicesPlaySystemSound(1104) }
                        isPressed = true
                        let tx = value.translation.width
                        let ty = value.translation.height
                        withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.6)) {
                            offset = CGSize(
                                width: tx * 0.3 / (1 + abs(tx) / 150),
                                height: ty * 0.3 / (1 + abs(ty) / 100)
                            )
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.35)) {
                            offset = .zero
                        }
                        action()
                    }
            )
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: isPressed)
    }
}
