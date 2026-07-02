//
//  Rhythm.swift
//  Luminous — the day's shape, computed from the life-event log
//
//  Pure and Foundation-only (in the SwiftPM test package). Turns a stream of
//  sensed state transitions ("sense.activity" → still/walking/transit,
//  "sense.place" → cafe/library/…) into dwell time: how long each state held,
//  today's minutes per state, and an hour-of-week histogram — the substrate for
//  free-time inference and the mentality estimate. Never a scoreboard: this
//  is weather-map data about the day, not a grade of it.
//

import Foundation

/// One observed state change, e.g. ("2026-06-30 14:02", "still").
struct SenseSample: Hashable {
    let time: Date
    let state: String
    init(time: Date, state: String) { self.time = time; self.state = state }
}

/// A stretch of time spent in one state.
struct DwellSegment: Hashable {
    let state: String
    let start: Date
    let minutes: Double
}

enum Rhythm {

    /// Fold transitions into dwell segments. A state holds until the next
    /// sample; the final one holds until `now`. Segments are capped (default
    /// 2 h) so a dead app or lost signal never fabricates a huge dwell.
    static func segments(_ samples: [SenseSample],
                         now: Date,
                         capMinutes: Double = 120) -> [DwellSegment] {
        let sorted = samples.sorted { $0.time < $1.time }
        var out: [DwellSegment] = []
        for (i, s) in sorted.enumerated() {
            let end = i + 1 < sorted.count ? sorted[i + 1].time : now
            let mins = end.timeIntervalSince(s.time) / 60
            guard mins > 0 else { continue }
            out.append(DwellSegment(state: s.state, start: s.time,
                                    minutes: min(mins, capMinutes)))
        }
        return out
    }

    /// Total minutes per state within [from, to).
    static func minutesByState(_ segments: [DwellSegment],
                               from: Date, to: Date) -> [String: Double] {
        var acc: [String: Double] = [:]
        for seg in segments {
            let segEnd = seg.start.addingTimeInterval(seg.minutes * 60)
            let s = max(seg.start, from), e = min(segEnd, to)
            let mins = e.timeIntervalSince(s) / 60
            if mins > 0 { acc[seg.state, default: 0] += mins }
        }
        return acc
    }

    /// Hour-of-week histogram: state → 168 bins (Mon 0h = 0 … Sun 23h = 167)
    /// of dwell minutes. The rhythm prior: "Tuesday 21:00 you're usually home
    /// and still."
    static func hourOfWeek(_ segments: [DwellSegment],
                           calendar: Calendar = .current) -> [String: [Double]] {
        var out: [String: [Double]] = [:]
        for seg in segments {
            var cursor = seg.start
            var remaining = seg.minutes
            while remaining > 0 {
                let bin = binIndex(cursor, calendar: calendar)
                // minutes left inside this clock hour
                let minuteOfHour = Double(calendar.component(.minute, from: cursor))
                let inHour = min(remaining, 60 - minuteOfHour)
                var bins = out[seg.state] ?? Array(repeating: 0, count: 168)
                bins[bin] += inHour
                out[seg.state] = bins
                cursor = cursor.addingTimeInterval(inHour * 60)
                remaining -= inHour
            }
        }
        return out
    }

    /// Monday-0-based hour-of-week bin for a date.
    static func binIndex(_ date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)   // 1 = Sunday
        let mondayBased = (weekday + 5) % 7                      // 0 = Monday
        let hour = calendar.component(.hour, from: date)
        return mondayBased * 24 + hour
    }

    /// A soft one-line summary of today ("坐着 3 小时 · 走动 40 分钟") for the
    /// Settings sensing panel. Never judgmental — just what the day held.
    static func todayLine(_ samples: [SenseSample],
                          now: Date,
                          calendar: Calendar = .current) -> String? {
        let start = calendar.startOfDay(for: now)
        let byState = minutesByState(segments(samples, now: now), from: start, to: now)
        guard !byState.isEmpty else { return nil }
        let names: [(String, String)] = [("still", "安坐"), ("walking", "走动"), ("transit", "在路上")]
        var bits: [String] = []
        for (key, label) in names {
            if let m = byState[key], m >= 5 { bits.append("\(label) \(fmt(m))") }
        }
        return bits.isEmpty ? nil : "今天到现在：" + bits.joined(separator: " · ")
    }

    private static func fmt(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m) 分钟" }
        let h = m / 60, rem = m % 60
        return rem == 0 ? "\(h) 小时" : "\(h) 小时 \(rem) 分"
    }
}
