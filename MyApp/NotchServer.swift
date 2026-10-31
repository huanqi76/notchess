import SwiftUI
import Network
import DynamicNotchKit

// replace with puzzles later
struct NotchContent: View {
    private let position: ChessPosition
    private let solverIsWhite: Bool

    init() {
        // Demo puzzle. In the real data, the first move belongs to the opponent,
        // and the moves after it are the ones you have to find.
        let fen = "6k1/5ppp/8/8/8/8/5PPP/R3K3 b - - 0 1"
        let moves = ["g8h8", "a1a8"]

        var pos = ChessPosition(fen: fen)
        solverIsWhite = !pos.whiteToMove    // whoever is NOT moving first is the solver
        pos.apply(uci: moves[0])            // play the opponent's move
        position = pos
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(solverIsWhite ? "White to move" : "Black to move")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ChessBoardView(position: position, flipped: !solverIsWhite, squareSize: 30)
        }
        .padding(12)
    }
}

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

// Decides when the notch appears, grows, shrinks and disappears
@MainActor
final class NotchController {
    // ---- Settings you can tune ----
    private let delaySeconds: Double = 5           // wait before showing the dot
    private let triggerHalfWidth: CGFloat = 130    // how far left/right of center opens it
    private let triggerHeight: CGFloat = 30        // how far down from the top edge opens it
    private let keepOpenHalfWidth: CGFloat = 320   // while open, the area where it stays open
    private let keepOpenHeight: CGFloat = 230
    private let collapseDelayMs = 100              // grace period before shrinking

    // ---- State ----
    private var pendingTask: Task<Void, Never>?    // the start countdown
    private var collapseTask: Task<Void, Never>?   // the shrink countdown
    private var mouseMonitor: Any?
    private var isExpanded = false

    private var expandAction: (() async -> Void)?
    private var compactAction: (() async -> Void)?
    private var hideAction: (() async -> Void)?

    func handle(_ path: String) {
        switch path {
        case "/start": start()
        case "/stop": stop()
        default: break
        }
    }

    private func start() {
        guard pendingTask == nil, hideAction == nil else { return }

        pendingTask = Task {
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard !Task.isCancelled else { return }
            await showCompact()
        }
    }

    private func showCompact() async {
        let notch = DynamicNotch {
            NotchContent()
        } compactLeading: {
            PulsingDot()
        } compactTrailing: {
            EmptyView()
        }
        
        notch.transitionConfiguration = .init(
            openingAnimation: .spring(duration: 0.15, bounce: 0),
            skipIntermediateHides: true
        )

        expandAction = { await notch.expand() }
        compactAction = { await notch.compact() }
        hideAction = { await notch.hide() }

        startWatchingMouse()
        await notch.compact()
    }

    private func startWatchingMouse() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            Task { @MainActor in self?.mouseMoved() }
        }
    }

    private func mouseMoved() {
        guard hideAction != nil, let screen = NSScreen.screens.first else { return }

        let mouse = NSEvent.mouseLocation
        let frame = screen.frame
        let distanceFromCenter = abs(mouse.x - frame.midX)
        let distanceFromTop = frame.maxY - mouse.y

        let inTriggerZone = distanceFromCenter < triggerHalfWidth && distanceFromTop < triggerHeight
        let inKeepOpenZone = distanceFromCenter < keepOpenHalfWidth && distanceFromTop < keepOpenHeight

        if !isExpanded {
            if inTriggerZone {
                isExpanded = true
                collapseTask?.cancel()
                collapseTask = nil
                Task { await expandAction?() }
            }
        } else {
            if inKeepOpenZone {
                collapseTask?.cancel()
                collapseTask = nil
            } else if collapseTask == nil {
                collapseTask = Task {
                    try? await Task.sleep(for: .milliseconds(collapseDelayMs))
                    guard !Task.isCancelled else { return }
                    isExpanded = false
                    collapseTask = nil
                    await compactAction?()
                }
            }
        }
    }

    private func stop() {
        pendingTask?.cancel()
        pendingTask = nil
        collapseTask?.cancel()
        collapseTask = nil

        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }

        isExpanded = false
        expandAction = nil
        compactAction = nil

        guard let action = hideAction else { return }
        hideAction = nil
        Task { await action() }
    }
}

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
