//
//  Places.swift
//  Luminous — the app slowly learns where home and work are, on-device
//
//  Pure and Foundation-only (in the SwiftPM test package). Location fixes are
//  coarsened to ~150 m grid cells the moment they arrive; only the cell key is
//  ever logged (never a raw coordinate), events age out at 90 days. Home is the
//  cell you most sleep in (night fixes), work the weekday-daytime cell — enough
//  for locationFit to be real ("在家" vs "在外面") without the app ever holding
//  a map of your life.
//

import Foundation

enum Places {

    /// Grid resolution in degrees. 0.0015° latitude ≈ 165 m — coarse enough to
    /// be a neighborhood block, fine enough to tell home from the office.
    static let cellSize = 0.0015

    /// A stable, coarse cell key for a coordinate ("31.230,121.474" style).
    static func cellKey(lat: Double, lon: Double) -> String {
        let qLat = (lat / cellSize).rounded() * cellSize
        let qLon = (lon / cellSize).rounded() * cellSize
        return String(format: "%.4f,%.4f", qLat, qLon)
    }

    /// One coarse observation: when + which cell.
    struct Observation: Hashable {
        let time: Date
        let cell: String
        init(time: Date, cell: String) { self.time = time; self.cell = cell }
    }

    /// Home = the modal cell of night observations (22:00–06:00). Requires a
    /// minimum of sightings so one late evening out never becomes "home".
    static func inferHome(_ obs: [Observation],
                          minCount: Int = 5,
                          calendar: Calendar = .current) -> String? {
        let night = obs.filter {
            let h = calendar.component(.hour, from: $0.time)
            return h >= 22 || h < 6
        }
        return modalCell(night, minCount: minCount)
    }

    /// Work = the modal cell of weekday daytime observations (Mon–Fri 9:00–18:00),
    /// and never the same cell as home (working from home just reads as home).
    static func inferWork(_ obs: [Observation],
                          home: String?,
                          minCount: Int = 5,
                          calendar: Calendar = .current) -> String? {
        let dayWork = obs.filter {
            let h = calendar.component(.hour, from: $0.time)
            let wd = calendar.component(.weekday, from: $0.time)   // 1 = Sunday
            return (2...6).contains(wd) && (9..<18).contains(h)
        }
        let cell = modalCell(dayWork, minCount: minCount)
        return cell == home ? nil : cell
    }

    private static func modalCell(_ obs: [Observation], minCount: Int) -> String? {
        var counts: [String: Int] = [:]
        for o in obs { counts[o.cell, default: 0] += 1 }
        guard let (cell, n) = counts.max(by: { $0.value < $1.value }), n >= minCount else {
            return nil
        }
        return cell
    }

    /// The coarse location hint for scoring, from the current cell + what's been
    /// learned. Transit motion wins; unknown places stay "outdoor" (the gentle
    /// default the scorer already treats as "out in the world").
    static func hint(currentCell: String?,
                     home: String?,
                     work: String?,
                     activity: Activity?) -> LocationType {
        if activity == .transit { return .transit }
        guard let cell = currentCell else { return .unknown }
        if let home, cell == home { return .home }
        if let work, cell == work { return .work }
        return .outdoor
    }
}
