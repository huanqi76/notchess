import SwiftUI

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
