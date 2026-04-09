//  ContentView.swift
//  Motion

import SwiftUI

struct ContentView: View {
    @State private var viewSize: CGSize = .zero

    var body: some View {
        ZStack {
            // Persistent shader background
            Rectangle()
                .fill(.white)
                .ignoresSafeArea()
                .colorEffect(
                    ShaderLibrary.welcomeBackground(
                        .float2(viewSize.width, viewSize.height),
                        .float(0.0)
                    )
                )
                .overlay(
                    GeometryReader { geo in
                        Color.clear.onAppear { viewSize = geo.size }
                    }
                )

            DemoView()
        }
    }
}

#Preview {
    ContentView()
}
