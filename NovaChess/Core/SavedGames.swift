import Foundation

public struct GameFolder: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public init(name: String) { self.name = name }
}
public struct SavedBoardGame: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var title: String
    public var date = Date()
    public var folderID: UUID?
    public var positions: [String]
    public var notation: [String]
    public init(title: String, positions: [String], notation: [String]) {
        self.title = title; self.positions = positions; self.notation = notation
    }
}
/// Only complete, repeatable observations matching exactly one legal next move advance the score sheet.
public struct CameraGameTracker: Sendable {
    public private(set) var positions: [Position] = [.initial]
    public private(set) var notation: [String] = []
    private var pending: String?
    private var repeats = 0
    public init() {}
    public var board: Position { positions.last ?? .initial }
    @discardableResult public mutating func observe(_ squares: [Piece?], uncertain: Set<Int>) throws -> Bool {
        guard squares.count == 64, uncertain.isEmpty else { pending = nil; repeats = 0; return false }
        guard squares != board.squares else { pending = nil; repeats = 0; return false }
        let matches = try board.legalMoves().filter { try board.playing($0).squares == squares }
        guard matches.count == 1, let move = matches.first else { pending = nil; repeats = 0; return false }
        if pending == move.uci { repeats += 1 } else { pending = move.uci; repeats = 1 }
        guard repeats >= 2 else { return false }
        let san = try board.san(for: move), next = try board.playing(move)
        positions.append(next); notation.append(san); pending = nil; repeats = 0
        return true
    }
    public mutating func recordManual(_ input: String) throws {
        let move = try board.move(forSAN: input)
        let san = try board.san(for: move), next = try board.playing(move)
        positions.append(next); notation.append(san); pending = nil; repeats = 0
    }
    public mutating func undo() {
        guard positions.count > 1 else { return }
        positions.removeLast(); notation.removeLast(); pending = nil; repeats = 0
    }
}
