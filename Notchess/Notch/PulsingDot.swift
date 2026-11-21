import SwiftUI

// A small dot that gently fades in and out
struct PulsingDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(.green)
            .frame(width: 8, height: 8)
            .opacity(pulse ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
