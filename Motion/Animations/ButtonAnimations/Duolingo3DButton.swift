
import SwiftUI
import AudioToolbox

struct Duolingo3DButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var pressed = false
    @State private var holding = false

    private var darkColor: Color { color.opacity(0.7) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(darkColor)
                .offset(y: pressed ? 1 : 5)
                .padding(.horizontal, 2)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .offset(y: pressed ? 4 : 0)

            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: pressed ? 4 : 0)
        }
        .frame(height: 54)
        .scaleEffect(x: pressed ? 0.98 : 1, y: pressed ? 0.96 : 1)
        .scaleEffect(holding ? 0.94 : 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        AudioServicesPlaySystemSound(1104)
                        withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) { pressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if pressed {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { holding = true }
                            }
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                        pressed = false; holding = false
                    }
                    action()
                }
        )
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: pressed)
    }
}
