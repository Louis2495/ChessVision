import Foundation
public enum TrainingAssets {
    private static func load<T: Decodable>(_ name: String) throws -> T {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw ChessError.invalid("This build is missing its \(name.lowercased()) library.") }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    public static func learning() throws -> ChessLearningContent { try load("Learning") }
    public static func puzzles() throws -> [ChessPuzzle] { try load("Puzzles") }
    public static func openings() throws -> [OpeningLine] { try load("Openings") }
}
