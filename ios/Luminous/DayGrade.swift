//
//  DayGrade.swift
//  Luminous — Direction B · Living World
//
//  Time-of-day color grading, ported from the web `lib/dayGrade.ts`.
//  Maps the current hour to a 3-stop sky palette (top → horizon → ground)
//  so the Home scene drifts dawn → noon → dusk → night with the real day.
//

import SwiftUI

enum DayPhase: String {
    case dawn, morning, noon, afternoon, dusk, night
}

enum DayGrade {
    static func phase(hour: Int) -> DayPhase {
        switch hour {
        case 5..<8:   return .dawn
        case 8..<11:  return .morning
        case 11..<15: return .noon
        case 15..<18: return .afternoon
        case 18..<21: return .dusk
        default:      return .night
        }
    }

    /// Three sky stops: [top, horizon, ground].
    static func colors(hour: Int) -> [Color] {
        switch phase(hour: hour) {
        case .dawn:      return [.hex("F6C7A4"), .hex("E8A0A0"), .hex("8E7BB0")]
        case .morning:   return [.hex("AFD3F2"), .hex("CFE8F5"), .hex("F3F6E9")]
        case .noon:      return [.hex("8FC7F4"), .hex("CDEBFB"), .hex("EAF6FF")]
        case .afternoon: return [.hex("F3D9A8"), .hex("EBC79A"), .hex("C9D9B0")]
        case .dusk:      return [.hex("E79A6B"), .hex("B06A86"), .hex("4A4A77")]
        case .night:     return [.hex("232A45"), .hex("1C2238"), .hex("121626")]
        }
    }

    /// A short poetic read of the moment (kept gentle — no commands).
    static func line(hour: Int) -> String {
        switch phase(hour: hour) {
        case .dawn:      return "天刚亮，慢慢来。"
        case .morning:   return "早上的光，刚刚好。"
        case .noon:      return "正午，留一个小空隙。"
        case .afternoon: return "下午的光，斜斜地照着。"
        case .dusk:      return "傍晚了，可以慢下来。"
        case .night:     return "夜里了，小小一件就好。"
        }
    }
}
