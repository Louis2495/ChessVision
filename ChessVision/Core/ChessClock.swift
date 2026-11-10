import Foundation

public struct ClockTimeControl: Equatable, Sendable {
    public let seconds: Int
    public let increment: Int
    public init(seconds: Int, increment: Int = 0) {
        self.seconds = min(86400, max(1, seconds)); self.increment = min(3600, max(0, increment))
    }
    public var title: String { seconds.isMultiple(of: 60) ? "\(seconds / 60) + \(increment)" : "\(seconds / 60):\(String(format: "%02d", seconds % 60)) + \(increment)" }
    public static let presets = [Self(seconds: 60), Self(seconds: 120, increment: 1), Self(seconds: 180), Self(seconds: 180, increment: 2), Self(seconds: 300), Self(seconds: 300, increment: 3), Self(seconds: 600), Self(seconds: 600, increment: 5), Self(seconds: 900, increment: 10), Self(seconds: 1800)]
}

public struct ChessClock: Sendable {
    public enum Phase: Equatable, Sendable { case ready, running, paused, finished }
    public private(set) var control: ClockTimeControl
    public private(set) var phase: Phase = .ready
    public private(set) var active: Side = .white
    private var white: Double
    private var black: Double
    private var anchor: Double?
    public init(control: ClockTimeControl = ClockTimeControl(seconds: 300)) {
        self.control = control; white = Double(control.seconds); black = Double(control.seconds)
    }
    public init(control: ClockTimeControl, white: Double, black: Double, active: Side) {
        self.control = control; self.white = white.isFinite ? max(0, white) : Double(control.seconds)
        self.black = black.isFinite ? max(0, black) : Double(control.seconds)
        self.active = active; phase = .paused
    }
    /// Callers use system uptime, so wall-clock changes cannot add or remove time.
    public func remaining(for side: Side, at now: Double) -> Double {
        let stored = side == .white ? white : black
        let elapsed = phase == .running && side == active ? max(0, now - (anchor ?? now)) : 0
        return max(0, stored - elapsed)
    }
    public var deadline: Double? { phase == .running ? anchor.map { $0 + (active == .white ? white : black) } : nil }
    public func flagged(at now: Double) -> Side? { remaining(for: active, at: now) <= 0 ? active : nil }
    public mutating func start(at now: Double) {
        guard phase == .ready || phase == .paused, flagged(at: now) == nil else { return }
        phase = .running; anchor = now
    }
    public mutating func press(_ side: Side, at now: Double) {
        if phase == .ready { active = side.opposite; start(at: now); return }
        guard phase == .running, side == active else { return }
        settle(at: now)
        guard phase != .finished else { return }
        if active == .white { white += Double(control.increment) } else { black += Double(control.increment) }
        active = active.opposite; anchor = now
    }
    public mutating func pause(at now: Double) {
        guard phase == .running else { return }
        settle(at: now)
        if phase != .finished { phase = .paused }
        anchor = nil
    }
    private mutating func settle(at now: Double) {
        let value = remaining(for: active, at: now)
        if active == .white { white = value } else { black = value }
        anchor = now
        if value <= 0 { phase = .finished; anchor = nil }
    }
}
