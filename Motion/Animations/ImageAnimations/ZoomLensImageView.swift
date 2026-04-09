import SwiftUI

struct ZoomLensImageView: View {
    @State private var lensPosition: CGPoint = .zero
    @State private var isLensActive = false

    private let imageWidth: CGFloat = 320
    private let imageHeight: CGFloat = 420
    private let lensSize: CGFloat = 120
    private let zoomFactor: CGFloat = 2.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ZStack {
                // Base image
                Image("eagle")
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Magnifying lens overlay
                if isLensActive {
                    ZStack {
                        Image("eagle")
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageWidth * zoomFactor, height: imageHeight * zoomFactor)
                            .offset(
                                x: -(lensPosition.x - imageWidth / 2) * zoomFactor,
                                y: -(lensPosition.y - imageHeight / 2) * zoomFactor
                            )
                    }
                    .frame(width: lensSize, height: lensSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .position(x: lensPosition.x, y: lensPosition.y)
                }
            }
            .frame(width: imageWidth, height: imageHeight)
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x, 0), imageWidth)
                        let y = min(max(value.location.y, 0), imageHeight)
                        lensPosition = CGPoint(x: x, y: y)
                        isLensActive = true
                    }
                    .onEnded { _ in
                        isLensActive = false
                    }
            )

            Text("drag to magnify")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    ZoomLensImageView()
}
