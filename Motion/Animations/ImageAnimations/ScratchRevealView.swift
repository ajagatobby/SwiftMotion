import SwiftUI

struct ScratchRevealView: View {
    @State private var scratchPaths: [[CGPoint]] = []
    @State private var currentPath: [CGPoint] = []

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("donald")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    Canvas { context, size in
                        // Draw gray cover
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.gray)
                        )

                        // Erase scratched areas
                        context.blendMode = .clear
                        let allPaths = scratchPaths + [currentPath]
                        for points in allPaths {
                            if points.count > 1 {
                                var path = Path()
                                path.move(to: points[0])
                                for pt in points.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                context.stroke(
                                    path,
                                    with: .color(.white),
                                    style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentPath.append(value.location)
                        }
                        .onEnded { _ in
                            scratchPaths.append(currentPath)
                            currentPath = []
                        }
                )
                .onTapGesture(count: 2) {
                    scratchPaths = []
                    currentPath = []
                }

            Text("scratch to reveal / double-tap to reset")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
    }
}

#Preview {
    ScratchRevealView()
}
