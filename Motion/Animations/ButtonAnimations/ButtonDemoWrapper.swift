
import SwiftUI

struct ButtonDemoWrapper<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            Color(white: 0.96).ignoresSafeArea()

            content()
                .padding(.horizontal, 40)
        }
    }
}
