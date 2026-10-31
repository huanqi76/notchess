import SwiftUI

// One piece on the board. The id stays the same as the piece moves,
// which is what lets SwiftUI slide it instead of redrawing it.
struct BoardPiece: Identifiable {
    let id: Int
    let kind: Character
    let square: Int
}

// A chess position: 64 squares, index 0 = a8, index 63 = h1 (the same order a FEN uses)
struct ChessPosition {
    var squares: [Character?]     // uppercase = white piece, lowercase = black piece
    var ids: [Int?]               // a unique id for each piece, moving along with it
    var whiteToMove: Bool
    var lastMove: (from: Int, to: Int)?

    init(fen: String, idBase: Int = 0) {
        let fields = fen.split(separator: " ")
        var parsed: [Character?] = []

        for ch in fields[0] {
            if ch == "/" { continue }
            if let emptyCount = ch.wholeNumberValue {
                parsed.append(contentsOf: [Character?](repeating: nil, count: emptyCount))
            } else {
                parsed.append(ch)
            }
        }

        squares = parsed
        ids = parsed.indices.map { i -> Int? in parsed[i] == nil ? nil : idBase + i }
        whiteToMove = fields.count > 1 ? (fields[1] == "w") : true
        lastMove = nil
    }

    var boardPieces: [BoardPiece] {
        squares.indices.compactMap { i in
            guard let kind = squares[i], let id = ids[i] else { return nil }
            return BoardPiece(id: id, kind: kind, square: i)
        }
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
            let captured = (from / 8) * 8 + toCol
            squares[captured] = nil
            ids[captured] = nil
        }

        // Castling: the king moves two files, so the rook comes along
        if isKing && abs(toCol - fromCol) == 2 {
            let row = from / 8
            let rookFrom = row * 8 + (toCol > fromCol ? 7 : 0)
            let rookTo = row * 8 + (toCol > fromCol ? 5 : 3)
            squares[rookTo] = squares[rookFrom]
            ids[rookTo] = ids[rookFrom]
            squares[rookFrom] = nil
            ids[rookFrom] = nil
        }

        // Promotion
        if chars.count == 5 {
            let promo = String(chars[4])
            piece = Character(piece.isUppercase ? promo.uppercased() : promo.lowercased())
        }

        squares[to] = piece
        ids[to] = ids[from]
        squares[from] = nil
        ids[from] = nil
        lastMove = (from, to)
    }
}

// One piece, drawn from the SVG artwork in Assets.xcassets (wK, bQ, ...)
struct PieceView: View {
    let piece: Character
    let size: CGFloat

    private var assetName: String {
        (piece.isUppercase ? "w" : "b") + piece.uppercased()
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// The 8x8 board: a layer of squares underneath, a layer of sliding pieces on top
struct ChessBoardView: View {
    let position: ChessPosition
    let flipped: Bool          // true = black at the bottom
    let squareSize: CGFloat
    var selected: Int? = nil
    var wrongSquare: Int? = nil
    var onTap: (Int) -> Void = { _ in }

    private let lightColor = Color(red: 0.93, green: 0.93, blue: 0.82)
    private let darkColor = Color(red: 0.46, green: 0.59, blue: 0.34)

    // Where a square is drawn on screen (accounts for flipping)
    private func displayCoords(_ square: Int) -> (col: Int, row: Int) {
        let row = square / 8
        let col = square % 8
        return (flipped ? 7 - col : col, flipped ? 7 - row : row)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: squares, highlights, and the tap targets
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

            // Layer 2: pieces. When a piece's square changes inside withAnimation, it slides.
            ForEach(position.boardPieces) { item in
                let spot = displayCoords(item.square)
                PieceView(piece: item.kind, size: squareSize)
                    .offset(x: CGFloat(spot.col) * squareSize, y: CGFloat(spot.row) * squareSize)
                    .transition(.opacity)
                    .allowsHitTesting(false)    // clicks fall through to the squares below
            }
        }
        .frame(width: squareSize * 8, height: squareSize * 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func squareView(row: Int, col: Int) -> some View {
        let index = row * 8 + col
        let isLight = (row + col) % 2 == 0
        ZStack {
            Rectangle().fill(isLight ? lightColor : darkColor)
            if let last = position.lastMove, index == last.from || index == last.to {
                Rectangle().fill(Color.orange.opacity(0.3))
            }
            if index == selected {
                Rectangle().fill(Color.yellow.opacity(0.5))
            }
            if index == wrongSquare {
                Rectangle().fill(Color.red.opacity(0.6))
            }
        }
        .frame(width: squareSize, height: squareSize)
        .contentShape(Rectangle())
        .onTapGesture { onTap(index) }
    }
}
