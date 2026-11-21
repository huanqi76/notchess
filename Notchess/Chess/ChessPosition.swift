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
