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

/// TestFlight, while testing picture matching: for each recent scan, what the label reading said and the 3 shop photos whose
/// fingerprints are nearest (worked out on GitHub every 30 minutes by print-check.yml). Nothing here changes what a scan shows.
struct FingerprintCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [Row] = []
    @State private var loading = true

    struct Hit: Identifiable { let id = UUID(); let wine: String; let producer: String; let dist: Double; let same: Bool; let sameProducer: Bool }
    struct Row: Identifiable { let id: Int; let key: String; let created: Date; let verdict: String; let note: String; let label: [Hit]; let whole: [Hit] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "TestFlight", title: "Fingerprint check",
                                 subtitle: "Each scan's picture compared with 182,000 shop photos. Checked on GitHub every 30 minutes, so a new scan shows up a little later.")
                    if loading { ProgressView().frame(maxWidth: .infinity).padding(.top, 20) }
                    else if rows.isEmpty {
                        Text("No checked scans yet. Scan a bottle with the camera, then look again in about 30 minutes.")
                            .font(.jero(size: 14)).foregroundStyle(Palette.inkSoft)
                    } else {
                        let same = rows.filter { $0.verdict == "same wine" }.count
                        let prod = rows.filter { $0.verdict == "same producer" }.count
                        Text("Picture agreed with the label reading on \(same) of \(rows.count) scans; same producer, other wine on \(prod).")
                            .font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                        ForEach(rows) { r in card(r) }
                    }
                }
                .padding(.horizontal, Metrics.margin).padding(.vertical, 12)
            }
            .background(Palette.paper.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func card(_ r: Row) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.nice(r.key)).font(.jero(size: 15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                Spacer(minLength: 6)
                Text(r.created.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(Palette.inkFaint)
            }
            Text(r.note.isEmpty ? r.verdict.capitalized : r.note)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(r.verdict == "same wine" ? Palette.correct : (r.verdict == "same producer" ? Palette.brass : Palette.wrong))
            if !r.label.isEmpty {
                Text("Label crops").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.inkSoft)
                ForEach(r.label) { hit($0) }
            }
            if !r.whole.isEmpty {
                Text("Whole photos").font(.system(size: 11.5, weight: .medium)).foregroundStyle(Palette.inkSoft).padding(.top, 2)
                ForEach(r.whole) { hit($0) }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: 0)
    }

    private func hit(_ h: Hit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: h.same ? "checkmark.circle.fill" : (h.sameProducer ? "circle.lefthalf.filled" : "xmark.circle"))
                .font(.system(size: 11)).foregroundStyle(h.same ? Palette.correct : (h.sameProducer ? Palette.brass : Palette.inkFaint))
            Text(h.wine).font(.system(size: 12.5)).foregroundStyle(Palette.ink).lineLimit(2)
            Spacer(minLength: 4)
            Text(String(format: "%.3f", h.dist)).font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.inkSoft)
        }
    }

    /// "guigal|cotes du rhone|2016" -> "Guigal · Cotes Du Rhone · 2016"
    static func nice(_ key: String) -> String {
        key.split(separator: "|").map { $0.capitalized }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func load() async {
        let raw = await PriceCloud.printChecks()
        func hits(_ a: Any?) -> [Hit] {
            (a as? [[String: Any]] ?? []).map { Hit(wine: $0["wine"] as? String ?? "", producer: $0["producer"] as? String ?? "",
                                                    dist: $0["dist"] as? Double ?? 0, same: $0["same"] as? Bool ?? false,
                                                    sameProducer: $0["sameProducer"] as? Bool ?? false) }
        }
        rows = raw.compactMap { r in
            guard let id = r["id"] as? Int else { return nil }
            let res = (r["results"] as? String).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            return Row(id: id, key: r["key"] as? String ?? "", created: Date(timeIntervalSince1970: TimeInterval(r["created"] as? Int ?? 0)),
                       verdict: res["verdict"] as? String ?? "", note: res["note"] as? String ?? "",
                       label: hits(res["label"]), whole: hits(res["whole"]))
        }
        loading = false
    }
}
