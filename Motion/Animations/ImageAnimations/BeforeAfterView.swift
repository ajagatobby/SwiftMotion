import SwiftUI

struct BeforeAfterView: View {
    @State private var dividerX: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                let width = min(geo.size.width - 40, 320)
                let xPos = dividerX * width

                ZStack {
                    // "After" -- original full color
                    Image("eagle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width)

                    // "Before" -- desaturated, clipped to left of divider
                    Image("eagle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: width)
                        .saturation(0)
                        .contrast(1.2)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: xPos)
                                Spacer()
                            }
                        )

                    // Divider line
                    Rectangle()
                        .fill(.white)
                        .frame(width: 3)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .position(x: xPos, y: geo.size.height / 2)

                    // Drag handle
                    Circle()
                        .fill(.white)
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black.opacity(0.5))
                        )
                        .position(x: xPos, y: geo.size.height / 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(width: width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let frameX = (geo.size.width - width) / 2
                            let relativeX = (value.location.x - frameX) / width
                            dividerX = min(max(relativeX, 0), 1)
                        }
                )
            }

            Text("drag to compare")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    BeforeAfterView()
}
