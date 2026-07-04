//
//  Recurrence.swift
//  Luminous — the tree finally reads its own rings
//
//  Pure and Foundation-only (in the SwiftPM test package). From the event log's
//  outcome moments it learns each wish's natural cadence ("you water this one
//  about every 4 days"), its favorite hour of day, and where it keeps not
//  fitting. The result is ONE clamped scoring term (±0.15) — never a streak,
//  never a count shown to the user, never punishment: repeated skips only teach
//  the wind where not to blow.
//

import Foundation

/// One remembered outcome: what happened to a wish, when, in which part of day.
struct Outcome: Hashable {
    enum Kind: String { case completed, partial, skipped }
    let time: Date
    let seedId: String
    let kind: Kind
    let semanticTime: SemanticTime?
    init(time: Date, seedId: String, kind: Kind, semanticTime: SemanticTime?) {
        self.time = time; self.seedId = seedId; self.kind = kind
        self.semanticTime = semanticTime
    }
}

enum Recurrence {

    /// What the rings say about one seed.
    struct SeedStats: Hashable {
        var completions = 0                       // completed + partial (partial counts!)
        var lastDone: Date?
        var medianGapDays: Double?
        var modalDoneTime: SemanticTime?
        var skipsByTime: [SemanticTime: Int] = [:]
        var doneByTime: [SemanticTime: Int] = [:]
        /// The pursuit's 手帐 page was touched (a note/idea kept) this week —
        /// a pursuit being thought about stays gently warm.
        var engagedRecently = false
    }

    /// Fold the outcome stream into per-seed stats.
    static func stats(_ outcomes: [Outcome]) -> [String: SeedStats] {
        var out: [String: SeedStats] = [:]
        var doneDates: [String: [Date]] = [:]
        for o in outcomes.sorted(by: { $0.time < $1.time }) {
            var s = out[o.seedId] ?? SeedStats()
            switch o.kind {
            case .completed, .partial:
                s.completions += 1
                s.lastDone = o.time
                doneDates[o.seedId, default: []].append(o.time)
                if let t = o.semanticTime { s.doneByTime[t, default: 0] += 1 }
            case .skipped:
                if let t = o.semanticTime { s.skipsByTime[t, default: 0] += 1 }
            }
            out[o.seedId] = s
        }
        for (id, dates) in doneDates where dates.count >= 2 {
            guard var s = out[id] else { continue }
            let gaps = zip(dates.dropFirst(), dates)
                .map { $0.timeIntervalSince($1) / 86_400 }
                .sorted()
            s.medianGapDays = gaps[gaps.count / 2]
            s.modalDoneTime = s.doneByTime.max { $0.value < $1.value }?.key
            out[id] = s
        }
        return out
    }

    /// The single history term, clamped to ±0.15:
    /// • a sleeping wish whose natural cadence has passed gently resurfaces;
    /// • a wish leans toward the part of day it actually gets done;
    /// • a context it keeps being skipped in offers it less often (fit-learning,
    ///   invisible and unpunishing — the wish itself never loses standing).
    static func historyBonus(_ seed: Seed,
                             _ ctx: ContextSnapshot,
                             stats: SeedStats?,
                             now: Date = Date()) -> Double {
        guard let s = stats else { return 0 }
        var b = 0.0

        if seed.status == .sleeping, let last = s.lastDone, let gap = s.medianGapDays, gap > 0 {
            let since = now.timeIntervalSince(last) / 86_400
            if since >= gap {
                b += min(0.15, 0.08 + 0.02 * (since / gap))   // due → gently rises
            }
        }
        if let modal = s.modalDoneTime, modal == ctx.semanticTime {
            b += 0.05
        }
        let skips = s.skipsByTime[ctx.semanticTime] ?? 0
        let dones = s.doneByTime[ctx.semanticTime] ?? 0
        if skips >= 3 && dones == 0 {
            b -= 0.1                                          // wrong moment, not wrong wish
        }
        if s.engagedRecently {
            b += 0.05                                         // being thought about = warm
        }
        return DomainUtil.clamp(b, -0.15, 0.15)
    }
}
