import Foundation

struct LockPolicy {
    static let cleaningDuration: TimeInterval = 180
    var deadline: TimeInterval?
    var isLocked: Bool { deadline != nil }
    mutating func begin(now: TimeInterval, duration: TimeInterval = LockPolicy.cleaningDuration) {
        deadline = now + min(max(duration, 1), 600)
    }
    mutating func stop() { deadline = nil }
    func remaining(now: TimeInterval) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline - now)))
    }
    func shouldBlock(type: UInt32, mediaKey: Bool, now: TimeInterval) -> Bool {
        guard let deadline, now < deadline else { return false }
        return [10, 11, 12].contains(type) || (type == 14 && mediaKey)
    }
}
