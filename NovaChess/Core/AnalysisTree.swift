import Foundation

public struct AnalysisNode: Identifiable, Sendable {
    public let id: UUID
    public let parent: UUID?
    public let position: Position
    public let san: String
    public var children: [UUID]
}
public struct AnalysisTree: Sendable {
    public private(set) var root: UUID
    public private(set) var nodes: [UUID: AnalysisNode]
    public init(position: Position) {
        let id = UUID(); root = id
        nodes = [id: AnalysisNode(id: id, parent: nil, position: position, san: "Start", children: [])]
    }
    @discardableResult public mutating func record(_ positions: [Position]) -> [UUID] {
        guard let first = positions.first else { return [] }
        if nodes[root]?.position != first { self = AnalysisTree(position: first) }
        var ids = [root]
        for position in positions.dropFirst() {
            guard let parent = ids.last, let before = nodes[parent]?.position else { break }
            if let match = nodes[parent]?.children.first(where: { nodes[$0]?.position == position }) { ids.append(match); continue }
            let move = before.legalMoves().first { (try? before.playing($0)) == position }
            let san = move.flatMap { try? before.san(for: $0) } ?? "Position edit"
            let id = UUID(); nodes[id] = AnalysisNode(id: id, parent: parent, position: position, san: san, children: [])
            nodes[parent]?.children.append(id); ids.append(id)
        }
        return ids
    }
    public func ids(for positions: [Position]) -> [UUID] {
        guard positions.first == nodes[root]?.position else { return [] }
        var result = [root]
        for position in positions.dropFirst() {
            guard let parent = result.last, let child = nodes[parent]?.children.first(where: { nodes[$0]?.position == position }) else { return [] }
            result.append(child)
        }
        return result
    }
    public func path(to id: UUID) -> [UUID] {
        var path: [UUID] = [], next: UUID? = id
        while let current = next, let node = nodes[current] { path.append(current); next = node.parent }
        return path.reversed()
    }
    public func continuation(from id: UUID) -> [UUID] {
        guard nodes[id] != nil else { return [] }
        var result = path(to: id), next = nodes[id]?.children.first
        while let child = next, let node = nodes[child] { result.append(child); next = node.children.first }
        return result
    }
    public var mainLine: [UUID] { continuation(from: root) }
    public var leaves: [UUID] {
        var pending = [root], result: [UUID] = []
        while let id = pending.popLast(), let node = nodes[id] {
            if node.children.isEmpty { result.append(id) }
            else { pending.append(contentsOf: node.children.reversed()) }
        }
        return result
    }
    public func positions(_ ids: [UUID]) -> [Position] { ids.compactMap { nodes[$0]?.position } }
    public mutating func promote(_ id: UUID) {
        for child in path(to: id).dropFirst() {
            guard let parent = nodes[child]?.parent else { continue }
            nodes[parent]?.children.removeAll { $0 == child }; nodes[parent]?.children.insert(child, at: 0)
        }
    }
    public mutating func demote(_ id: UUID) {
        guard let parent = nodes[id]?.parent, (nodes[parent]?.children.count ?? 0) > 1 else { return }
        nodes[parent]?.children.removeAll { $0 == id }; nodes[parent]?.children.append(id)
    }
    public mutating func delete(_ id: UUID) {
        guard let parent = nodes[id]?.parent else { return }
        nodes[parent]?.children.removeAll { $0 == id }
        var pending = [id]
        while let current = pending.popLast(), let node = nodes.removeValue(forKey: current) { pending.append(contentsOf: node.children) }
    }
}
