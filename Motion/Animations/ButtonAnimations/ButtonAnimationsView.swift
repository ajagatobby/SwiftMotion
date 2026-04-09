
import SwiftUI

struct ButtonAnimationsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Button Animations")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.top, 20)

                sectionHeader("3D Press")
                Duolingo3DButton(title: "Continue", color: Color(red: 0.35, green: 0.78, blue: 0.35)) {}

                sectionHeader("Jelly Bounce")
                JellyButton(title: "Tap Me", color: .blue) {}

                sectionHeader("Magnetic Pull")
                MagneticButton(title: "Hold & Drag", color: .purple) {}

                sectionHeader("Liquid Fill")
                LiquidFillButton(title: "Hold to Confirm", color: .orange) {}

                sectionHeader("Neon Glow")
                NeonGlowButton(title: "Glow", color: .cyan) {}

                sectionHeader("Elastic Pill")
                ElasticPillButton(title: "Subscribe", icon: "bell.fill", color: .pink) {}

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 30)
        }
        .background(Color(white: 0.96).ignoresSafeArea())
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ButtonAnimationsView()
}
