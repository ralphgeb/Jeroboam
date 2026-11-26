import Foundation
import SwiftUI

/// How long each step of a scan took ("Label 0.6 s · Claude 2.9 s · …"), so a slow scan on a real phone shows where its time
/// went. The last 30 scans are kept and listed in TestFlight builds only (Settings > TestFlight > Scan timings), never in the
/// scan screen itself. Steps are recorded from any thread.
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

    struct Record: Codable, Identifiable {
        var id = UUID()
        var date: Date
        var wine: String
        var steps: String
    }
    private static let key = "jero.scanTimings"

    /// The scans timed so far, newest first.
    static var records: [Record] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Record].self, from: d)) ?? []
    }

    /// The scan is over: keep its timings (TestFlight builds only).
    func finish(wine: String) {
        guard Distribution.isTestFlight else { return }
        let line = summary()
        guard !line.isEmpty else { return }
        let list = [Record(date: Date(), wine: wine.isEmpty ? "Unknown wine" : wine, steps: line)] + Self.records
        if let d = try? JSONEncoder().encode(Array(list.prefix(30))) { UserDefaults.standard.set(d, forKey: Self.key) }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    /// "Label 0.6 s · Lookup 0.8 s · Claude 2.9 s · … · total 9.4 s"
    func summary() -> String {
        lock.lock(); defer { lock.unlock() }
        guard !steps.isEmpty else { return "" }
        let parts = steps.map { "\($0.0) \(String(format: "%.1f", $0.1)) s" }
        return (parts + ["total " + String(format: "%.1f", Date().timeIntervalSince(began)) + " s"]).joined(separator: " · ")
    }
}

/// TestFlight: the last scans and how long each step took.
struct ScanTimingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var records = ScanClock.records

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "TestFlight", title: "Scan timings",
                                 subtitle: "How long each step of your last scans took, newest first.")
                    if records.isEmpty {
                        Text("Scan a wine and its timings show here.").font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
                    }
                    ForEach(records) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(r.wine).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11.5)).foregroundStyle(Palette.inkFaint)
                            }
                            Text(r.steps.replacingOccurrences(of: " · ", with: "\n"))
                                .font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Palette.inkSoft).textSelection(.enabled)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: 0)
                    }
                    if !records.isEmpty {
                        Button("Clear") { ScanClock.clear(); records = [] }
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.wine).frame(maxWidth: .infinity).padding(.top, 6)
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
