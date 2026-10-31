import SwiftUI
import DynamicNotchKit

@main
struct MyApp: App {
    var body: some Scene {
        MenuBarExtra("WaitTime", systemImage: "hourglass") {
            Button("Test notch") {
                Task {
                    let notch = DynamicNotch {
                        Text("Hello from the notch")
                            .padding()
                    }
                    await notch.expand()
                    try? await Task.sleep(for: .seconds(3))
                    await notch.hide()
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
