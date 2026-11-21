import SwiftUI
import DynamicNotchKit

// Decides when the notch appears, grows, shrinks and disappears
@MainActor
final class NotchController {
    // ---- Settings you can tune ----
    private let delaySeconds: Double = 5           // wait before showing the dot
    private let triggerHalfWidth: CGFloat = 130    // how far left/right of center opens it
    private let triggerHeight: CGFloat = 30        // how far down from the top edge opens it
    private let keepOpenHalfWidth: CGFloat = 320   // while open, the area where it stays open
    private let keepOpenHeight: CGFloat = 700
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
        let session = PuzzleSession()
        let notch = DynamicNotch {
            NotchContentView(session: session)
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
