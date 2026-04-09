import SwiftUI

struct CardFlipImageView: View {
    @State private var isFlipped = false
    @State private var rotation: Double = 0

    private var showFront: Bool {
        rotation < 90 || rotation > 270
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                ZStack {
                    if showFront {
                        Image("eagle")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    } else {
                        Image("eagle")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 360)
                            .saturation(0)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            .scaleEffect(x: -1)
                    }
                }
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .onTapGesture {
                    isFlipped.toggle()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        rotation = isFlipped ? 180 : 0
                    }
                }
            }

            Text("tap to flip")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    CardFlipImageView()
}
