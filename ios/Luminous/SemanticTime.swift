//
//  SemanticTime.swift
//  Luminous
//
//  Map a clock hour to a semantic time-of-day, build a ContextSnapshot.
//  Ported from lib/semanticTime.ts and lib/context.ts.
//

import Foundation

enum TimeOfDay {
    /// Late night is the protected window: 23:00–04:59.
    static func semanticTime(fromHour hour: Int, isWeekend: Bool = false) -> SemanticTime {
        if hour >= 23 || hour < 5 { return .lateNight }
        if isWeekend { return .weekend }
        if hour < 11 { return .morning }
        if hour < 14 { return .lunch }
        if hour < 17 { return .afternoon }
        if hour < 19 { return .afterWork }
        return .evening
    }

    static func isLateNight(hour: Int) -> Bool {
        hour >= 23 || hour < 5
    }

    static func isWeekend(_ date: Date = Date()) -> Bool {
        let d = Calendar.current.component(.weekday, from: date) // 1 = Sunday, 7 = Saturday
        return d == 1 || d == 7
    }

    static func semanticTime(from date: Date = Date()) -> SemanticTime {
        let hour = Calendar.current.component(.hour, from: date)
        return semanticTime(fromHour: hour, isWeekend: isWeekend(date))
    }
}

struct ContextInput {
    var mood: Mood
    var energy: Energy
    var freeMinutes: Int?
    var locationHint: LocationType?
    var isOutdoorWeatherGood: Bool?
    var now: Date = Date()
    var isMobile: Bool = true
    var isAtComputer: Bool?

    // Sensed (on-device), all optional.
    var activity: Activity?
    var ambient: Ambient?
    var arousal: Arousal?
    var weatherKind: WeatherKind?
}

enum ContextBuilder {
    /// Build a ContextSnapshot from the small set of things the user tells us
    /// plus device/time signals we can infer without sensitive data.
    static func build(_ input: ContextInput) -> ContextSnapshot {
        let now = input.now
        let weekend = TimeOfDay.isWeekend(now)
        let hour = Calendar.current.component(.hour, from: now)
        return ContextSnapshot(
            timestamp: DomainUtil.nowIso(),
            semanticTime: TimeOfDay.semanticTime(from: now),
            mood: input.mood,
            energy: input.energy,
            freeMinutes: input.freeMinutes,
            isLateNight: TimeOfDay.isLateNight(hour: hour),
            isWeekend: weekend,
            isOutdoorWeatherGood: input.isOutdoorWeatherGood,
            locationHint: input.locationHint,
            deviceContext: DeviceContext(isMobile: input.isMobile, isAtComputer: input.isAtComputer),
            activity: input.activity,
            ambient: input.ambient,
            arousal: input.arousal,
            weatherKind: input.weatherKind
        )
    }
}
