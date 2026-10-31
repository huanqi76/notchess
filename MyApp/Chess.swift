import SwiftUI

// A chess position: 64 squares, index 0 = a8, index 63 = h1
struct ChessPosition {
    var squares: [Character?]    // uppercase = white piece, lowercase = black piece
    var whiteToMove: Bool

    init(fen: String) {
        let fields = fen.split(separator: " ")
        var result: [Character?] = []

        for ch in fields[0] {
            if ch == "/" { continue }
            if let emptyCount = ch.wholeNumberValue {
                result.append(contentsOf: [Character?](repeating: nil, count: emptyCount))
            } else {
                result.append(ch)
            }
        }

        squares = result
        whiteToMove = fields.count > 1 ? (fields[1] == "w") : true
    }

    // Turns "e" and "4" into a square index
    static func index(file: Character, rank: Character) -> Int? {
        guard let f = file.asciiValue,
              let r = rank.wholeNumberValue,
              f >= 97, f <= 104, r >= 1, r <= 8 else { return nil }
        return (8 - r) * 8 + Int(f - 97)
    }

    // Plays a move written like "e2e4" (or "e7e8q" for promotion)
    mutating func apply(uci: String) {
        let chars = Array(uci)
        guard chars.count >= 4,
              let from = ChessPosition.index(file: chars[0], rank: chars[1]),
              let to = ChessPosition.index(file: chars[2], rank: chars[3]),
              var piece = squares[from] else { return }

        let isPawn = piece.lowercased() == "p"
        let isKing = piece.lowercased() == "k"
        let fromCol = from % 8
        let toCol = to % 8

        // En passant: a pawn moving diagonally onto an empty square captures the pawn beside it
        if isPawn && fromCol != toCol && squares[to] == nil {
            squares[(from / 8) * 8 + toCol] = nil
        }

        // Castling: the king moves two files, so the rook has to come along
        if isKing && abs(toCol - fromCol) == 2 {
            let row = from / 8
            if toCol > fromCol {
                squares[row * 8 + 5] = squares[row * 8 + 7]
                squares[row * 8 + 7] = nil
            } else {
                squares[row * 8 + 3] = squares[row * 8 + 0]
                squares[row * 8 + 0] = nil
            }
        }

        // Promotion
        if chars.count == 5 {
            let promo = String(chars[4])
            piece = Character(piece.isUppercase ? promo.uppercased() : promo.lowercased())
        }

        squares[to] = piece
        squares[from] = nil
    }
}

// One piece, drawn as a text symbol with an outline so it shows on both square colors
struct PieceView: View {
    let piece: Character
    let size: CGFloat

    private var glyph: String {
        switch piece.lowercased() {
        case "k": return "\u{265A}"
        case "q": return "\u{265B}"
        case "r": return "\u{265C}"
        case "b": return "\u{265D}"
        case "n": return "\u{265E}"
        case "p": return "\u{265F}\u{FE0E}"   // the FE0E stops macOS from turning it into an emoji
        default: return ""
        }
    }

    var body: some View {
        let isWhite = piece.isUppercase
        Text(glyph)
            .font(.system(size: size * 0.8))
            .foregroundStyle(isWhite ? Color.white : Color.black)
            .shadow(color: isWhite ? .black : .white.opacity(0.7), radius: 0.8)
            .shadow(color: isWhite ? .black : .white.opacity(0.7), radius: 0.8)
    }
}

// The 8x8 board
struct ChessBoardView: View {
    let position: ChessPosition
    let flipped: Bool          // true = black at the bottom
    let squareSize: CGFloat

    private let lightColor = Color(red: 0.93, green: 0.93, blue: 0.82)
    private let darkColor = Color(red: 0.46, green: 0.59, blue: 0.34)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { displayRow in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { displayCol in
                        let row = flipped ? 7 - displayRow : displayRow
                        let col = flipped ? 7 - displayCol : displayCol
                        squareView(row: row, col: col)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func squareView(row: Int, col: Int) -> some View {
        let isLight = (row + col) % 2 == 0
        ZStack {
            Rectangle().fill(isLight ? lightColor : darkColor)
            if let piece = position.squares[row * 8 + col] {
                PieceView(piece: piece, size: squareSize)
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
}
