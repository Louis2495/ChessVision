import Foundation

public enum ApplicationStorage {
    /// The legacy name is retained only for restoring an old app-container backup.
    /// A different Apple bundle ID cannot access the old installed app's sandbox.
    public static func directory(in base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) -> URL {
        let manager = FileManager.default
        let destination = base.appendingPathComponent("NovaChess", isDirectory: true)
        let legacy = base.appendingPathComponent("ChessVision", isDirectory: true)
        guard !manager.fileExists(atPath: destination.path), manager.fileExists(atPath: legacy.path) else { return destination }
        let temporary = base.appendingPathComponent("NovaChess-migration-" + UUID().uuidString, isDirectory: true)
        do {
            try manager.copyItem(at: legacy, to: temporary)
            try manager.moveItem(at: temporary, to: destination)
            return destination
        } catch {
            try? manager.removeItem(at: temporary)
            return legacy // Preserve readable progress rather than starting an empty library.
        }
    }
}
