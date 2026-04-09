
import SwiftUI
import AudioToolbox

struct NeonGlowButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    @State private var glowing = false
    @State private var pressed = false
    @State private var holding = false
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(color, lineWidth: holding ? 3 : 2)
            )
            .shadow(color: color.opacity(holding ? 0.9 : (glowing ? 0.8 : 0.3)), radius: holding ? 24 : (glowing ? 16 : 6))
            .shadow(color: color.opacity(holding ? 0.5 : (glowing ? 0.4 : 0.1)), radius: holding ? 40 : (glowing ? 30 : 10))
            .scaleEffect(pressed ? 0.95 : 1)
            .scaleEffect(pulseScale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            AudioServicesPlaySystemSound(1104)
                            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) { pressed = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                if pressed {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { holding = true }
                                    withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.03
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                            pressed = false; holding = false; pulseScale = 1
                        }
                        action()
                    }
            )
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.5), trigger: pressed)
    }
}
