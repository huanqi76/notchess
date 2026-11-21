import Foundation
import Network

// Listens on localhost:7777 and reports the path of each request
final class LocalServer {
    private var listener: NWListener?
    private let onEvent: @Sendable (String) -> Void

    init(onEvent: @escaping @Sendable (String) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredInterfaceType = .loopback   // this Mac only
            let listener = try NWListener(using: params, on: 7777)

            listener.stateUpdateHandler = { state in
                print("Listener state:", state)
            }

            listener.newConnectionHandler = { [onEvent] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    if let data, let text = String(data: data, encoding: .utf8) {
                        // First line looks like: "GET /start HTTP/1.1"
                        let firstLine = text.components(separatedBy: "\r\n").first ?? ""
                        let parts = firstLine.split(separator: " ")
                        if parts.count >= 2 {
                            onEvent(String(parts[1]))
                        }
                    }
                    let reply = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"
                    connection.send(content: reply.data(using: .utf8),
                                    completion: .contentProcessed { _ in connection.cancel() })
                }
            }

            listener.start(queue: .main)
            self.listener = listener
        } catch {
            print("Could not start listener:", error)
        }
    }
}
