//
//  WaterReflectionView.swift
//  Motion

import SwiftUI
import Combine

struct WaterReflectionView: View {
    @State private var time: Double = 0
    @State private var intensity: Double = 1.0
    @State private var touchLocation: CGPoint = .zero
    @State private var touchActive: Double = 0.0

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image("eagle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(40)
                .layerEffect(
                    ShaderLibrary.waterReflection(
                        .float2(320, 480),
                        .float(time),
                        .float(intensity),
                        .float(touchLocation.x),
                        .float(touchLocation.y),
                        .float(touchActive)
                    ),
                    maxSampleOffset: CGSize(width: 20, height: 400)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchLocation = value.location
                            withAnimation(.easeOut(duration: 0.15)) {
                                touchActive = 1.0
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.6)) {
                                touchActive = 0.0
                            }
                        }
                )

            Text("drag to ripple")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.3))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 50)
        }
        .onReceive(timer) { _ in
            time += 1.0 / 60.0
        }
    }
}

#Preview {
    WaterReflectionView()
}
