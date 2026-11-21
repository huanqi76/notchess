import Foundation

struct PuzzleData {
    let id: String
    let fen: String
    let moves: [String]
    let rating: Int

    // Used only if puzzles.csv can't be found
    static let demo = PuzzleData(
        id: "demo",
        fen: "6k1/5ppp/8/8/8/8/5PPP/R3K3 b - - 0 1",
        moves: ["g8f8", "a1a8", "f8e7", "a8a7"],
        rating: 0
    )
}

enum PuzzleLibrary {
    static let all: [PuzzleData] = load()

    static func random() -> PuzzleData? {
        all.randomElement()
    }

    private static func load() -> [PuzzleData] {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            print("⚠️ puzzles.csv not found in the app bundle. Using the demo puzzle.")
            return []
        }

        let puzzles: [PuzzleData] = text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 4, let rating = Int(fields[3]) else { return nil }
            let moves = fields[2].split(separator: " ").map(String.init)
            guard moves.count >= 2 else { return nil }
            return PuzzleData(id: String(fields[0]), fen: String(fields[1]), moves: moves, rating: rating)
        }

        print("Loaded \(puzzles.count) puzzles.")
        return puzzles
    }
}
