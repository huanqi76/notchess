import SwiftUI

struct NotchContentView: View {
    @ObservedObject var session: PuzzleSession

    private var statusText: String {
        switch session.status {
        case .solving: return session.solverIsWhite ? "White to move" : "Black to move"
        case .wrong: return "Not quite, try again"
        case .solved: return "Solved ✓"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .solving: return Color.secondary
        case .wrong: return Color.red
        case .solved: return Color.green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                Spacer()
                Text("\(session.rating)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Skip") { session.skip() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240)

            ChessBoardView(
                position: session.position,
                flipped: !session.solverIsWhite,
                squareSize: 30,
                selected: session.selected,
                wrongSquare: session.wrongSquare,
                onTap: { session.tap($0) }
            )
        }
        .padding(12)
    }
}
