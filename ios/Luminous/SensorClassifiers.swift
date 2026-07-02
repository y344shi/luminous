//
//  SensorClassifiers.swift
//  Luminous — the pure half of sensing (verbatim from @core/sensors + @core/weather)
//
//  Foundation-only, no platform frameworks: these classifiers are shared with the
//  SwiftPM test package (ios/Package.swift) so the thresholds stay pinned by tests.
//  The platform sampler that feeds them lives in Sensors.swift.
//

import Foundation

enum Sensors {
    /// magnitudes → still | walking | transit (mean-abs-deviation; needs ≥4 samples).
    static func classifyActivity(_ magnitudes: [Double]) -> Activity? {
        guard magnitudes.count >= 4 else { return nil }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let mad = magnitudes.reduce(0) { $0 + abs($1 - mean) } / Double(magnitudes.count)
        if mad < 0.6 { return .still }
        if mad < 3.5 { return .walking }
        return .transit
    }

    /// rms → quiet | lively (`rms >= 0.08` → lively).
    static func classifyAmbient(_ rms: Double) -> Ambient {
        rms >= 0.08 ? .lively : .quiet
    }

    /// bpm → calm | elevated (`bpm >= resting + 18` → elevated).
    static func classifyArousal(_ bpm: Double, resting: Double = 70) -> Arousal {
        bpm >= resting + 18 ? .elevated : .calm
    }
}

// MARK: - Weather mapping (mirrors @core/weather)

enum Weather {
    /// open-meteo WMO weather code → coarse kind.
    static func classify(code: Int) -> WeatherKind {
        switch code {
        case 0, 1:           return .clear
        case 2, 3:           return .clouds
        case 45, 48:         return .fog
        case 51...67, 80...82, 95...99: return .rain
        case 71...77, 85, 86: return .snow
        default:             return .unknown
        }
    }

    /// Good to be outside: clear/cloudy and mild.
    static func isGoodOutdoor(kind: WeatherKind, tempC: Double) -> Bool {
        (kind == .clear || kind == .clouds) && tempC >= 8 && tempC <= 30
    }
}
