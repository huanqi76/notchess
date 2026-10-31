import SwiftUI
import DynamicNotchKit

@main
struct MyApp: App {
    private let server: LocalServer

    init() {
        let controller = NotchController()
        server = LocalServer { path in
            Task { @MainActor in
                controller.handle(path)
            }
        }
        server.start()
    }

    var body: some Scene {
        MenuBarExtra("MyApp", systemImage: "hourglass") {
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
