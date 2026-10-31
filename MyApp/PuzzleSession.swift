import SwiftUI
import Combine

enum PuzzleStatus {
    case solving, wrong, solved
}

@MainActor
final class PuzzleSession: ObservableObject {
    @Published private(set) var position = ChessPosition(fen: "8/8/8/8/8/8/8/8 w - - 0 1")
    @Published private(set) var selected: Int?
    @Published private(set) var wrongSquare: Int?
    @Published private(set) var status: PuzzleStatus = .solving
    @Published private(set) var solverIsWhite = true
    @Published private(set) var rating = 0

    private var moves: [String] = []
    private var moveIndex = 1
    private var isBusy = false
    private var generation = 0      // changes with every new puzzle, so stale timers can bail out

    init() {
        loadNext()
    }

    func loadNext() {
        generation += 1
        let gen = generation
        let puzzle = PuzzleLibrary.random() ?? PuzzleData.demo

        let pos = ChessPosition(fen: puzzle.fen, idBase: gen * 100)
        solverIsWhite = !pos.whiteToMove
        moves = puzzle.moves
        rating = puzzle.rating

        position = pos              // the board before the opponent's move
        moveIndex = 1
        selected = nil
        wrongSquare = nil
        status = .solving
        isBusy = true               // locked until the opponent's move has played

        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard gen == generation else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                position.apply(uci: moves[0])
            }
            isBusy = false
        }
    }

    func skip() {
        loadNext()
    }

    func tap(_ square: Int) {
        guard status != .solved, !isBusy else { return }

        let piece = position.squares[square]
        let isMine = piece.map { $0.isUppercase == solverIsWhite } ?? false

        if let from = selected {
            if square == from {
                selected = nil
            } else if isMine {
                selected = square
            } else {
                attemptMove(from: from, to: square)
            }
        } else if isMine {
            selected = square
        }
    }

    private func attemptMove(from: Int, to: Int) {
        let attempt = Self.name(of: from) + Self.name(of: to)
        let expected = moves[moveIndex]
        let gen = generation
        selected = nil

        if attempt == String(expected.prefix(4)) {
            withAnimation(.easeInOut(duration: 0.2)) {
                position.apply(uci: expected)
            }
            moveIndex += 1
            isBusy = true

            if moveIndex >= moves.count {
                status = .solved
                Task {
                    try? await Task.sleep(for: .milliseconds(1200))
                    guard gen == generation else { return }
                    loadNext()
                }
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard gen == generation else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        position.apply(uci: moves[moveIndex])
                    }
                    moveIndex += 1
                    isBusy = false
                }
            }
        } else {
            isBusy = true
            status = .wrong
            wrongSquare = to
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                guard gen == generation else { return }
                wrongSquare = nil
                status = .solving
                isBusy = false
            }
        }
    }

    private static func name(of index: Int) -> String {
        let files = Array("abcdefgh")
        return "\(files[index % 8])\(8 - index / 8)"
    }
}
