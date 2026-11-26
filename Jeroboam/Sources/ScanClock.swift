import Foundation

/// How long each step of a scan took, shown under the result in TestFlight builds only ("Label 0.6 s · Lookup 0.8 s · …"),
/// so a slow scan on a real phone shows where its time went. Steps are recorded from any thread.
final class ScanClock: @unchecked Sendable {
    static let shared = ScanClock()
    private let lock = NSLock()
    private var steps: [(String, Double)] = []
    private var began = Date()

    /// A new scan: forget the last one's steps.
    func start() { lock.lock(); steps = []; began = Date(); lock.unlock() }

    /// One finished step, timed from `since`.
    func add(_ name: String, since: Date) {
        let s = Date().timeIntervalSince(since)
        lock.lock(); steps.append((name, s)); lock.unlock()
    }

    /// "Label 0.6 s · Lookup 0.8 s · Claude 2.9 s · … · total 9.4 s"
    func summary() -> String {
        lock.lock(); defer { lock.unlock() }
        guard !steps.isEmpty else { return "" }
        let parts = steps.map { "\($0.0) \(String(format: "%.1f", $0.1)) s" }
        return (parts + ["total " + String(format: "%.1f", Date().timeIntervalSince(began)) + " s"]).joined(separator: " · ")
    }
}
