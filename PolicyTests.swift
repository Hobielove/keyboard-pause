import Foundation

@main struct PolicyTests {
    static func main() {
        var lock = LockPolicy()
        precondition(!lock.shouldBlock(type: 10, mediaKey: false, now: 100))
        lock.begin(now: 100)
        precondition(lock.remaining(now: 100) == 180)
        precondition(lock.shouldBlock(type: 10, mediaKey: false, now: 279.99))
        precondition(!lock.shouldBlock(type: 10, mediaKey: false, now: 280))
        lock.stop()
        lock.begin(now: 100, duration: 60)
        for event: UInt32 in [10, 11, 12] {
            precondition(lock.shouldBlock(type: event, mediaKey: false, now: 159.99))
            precondition(!lock.shouldBlock(type: event, mediaKey: false, now: 160))
        }
        for event: UInt32 in [1, 2, 3, 4, 5, 6, 7, 22, 25, 26, 27] {
            precondition(!lock.shouldBlock(type: event, mediaKey: false, now: 110))
        }
        precondition(lock.shouldBlock(type: 14, mediaKey: true, now: 110))
        precondition(!lock.shouldBlock(type: 14, mediaKey: false, now: 110))
        precondition(lock.remaining(now: 159.9) == 1)
        precondition(lock.remaining(now: 160) == 0)
        lock.stop()
        precondition(!lock.isLocked)
        precondition(!lock.shouldBlock(type: 10, mediaKey: false, now: 110))
        lock.begin(now: 0, duration: 9999)
        precondition(lock.remaining(now: 0) == 600)
        lock.begin(now: 0, duration: -10)
        precondition(lock.remaining(now: 0) == 1)
        print("PASS: key filtering, mouse passthrough, media subtype, deadline, stop and duration limits")
    }
}
