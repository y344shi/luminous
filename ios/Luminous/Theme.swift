//
//  Theme.swift
//  Luminous
//
//  Theme tokens + design constants, ported from lib/themes.ts.
//  CSS variables become a SwiftUI environment value.
//

import SwiftUI

struct ThemeTokens {
    let background: Color
    let surface: Color
    let surfaceSoft: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let accentSoft: Color
    /// Darker accent for accent-colored text (links, active nav) on light surfaces.
    let accentText: Color
    /// Foreground color for text/icons placed ON the accent (e.g. primary button).
    let onAccent: Color
    let border: Color
}

struct ThemeStyle {
    let label: String
    let feeling: String
}

enum Theme {
    static let tokens: [ThemeName: ThemeTokens] = [
        .warmPaper: ThemeTokens(
            background: .hex("F8F4EC"), surface: .hex("FFFDF8"), surfaceSoft: .hex("F1EADF"),
            textPrimary: .hex("26231F"), textSecondary: .hex("6B6357"), textMuted: .hex("827868"),
            accent: .hex("7D9A7A"), accentSoft: .hex("DDE8D8"), accentText: .hex("4C6549"),
            onAccent: .hex("211E19"), border: .hex("E6DCCC")),
        .duskGarden: ThemeTokens(
            background: .hex("EEF0F4"), surface: .hex("FAF7F2"), surfaceSoft: .hex("E7E1EC"),
            textPrimary: .hex("252A35"), textSecondary: .hex("565E6E"), textMuted: .hex("666E80"),
            accent: .hex("D7A35F"), accentSoft: .hex("F2DFC1"), accentText: .hex("7A5822"),
            onAccent: .hex("221A12"), border: .hex("D8D5DF")),
        .minimalIos: ThemeTokens(
            background: .hex("F7F7F8"), surface: .hex("FFFFFF"), surfaceSoft: .hex("EFEFF3"),
            textPrimary: .hex("111111"), textSecondary: .hex("5E5E5E"), textMuted: .hex("79797F"),
            accent: .hex("6E8FBF"), accentSoft: .hex("E7EEF8"), accentText: .hex("3F6196"),
            onAccent: .hex("0E2236"), border: .hex("E5E5EA")),
        .fieldNotebook: ThemeTokens(
            background: .hex("F1F4EA"), surface: .hex("FFFDF4"), surfaceSoft: .hex("E3EAD8"),
            textPrimary: .hex("243024"), textSecondary: .hex("586353"), textMuted: .hex("727B66"),
            accent: .hex("758B5A"), accentSoft: .hex("DDE8C8"), accentText: .hex("4E6438"),
            onAccent: .hex("131A0E"), border: .hex("D7DDC8")),
        .softRitual: ThemeTokens(
            background: .hex("27231F"), surface: .hex("332D27"), surfaceSoft: .hex("40372F"),
            textPrimary: .hex("FFF3E0"), textSecondary: .hex("D9C7AE"), textMuted: .hex("B5A48E"),
            accent: .hex("D6A45F"), accentSoft: .hex("5A442C"), accentText: .hex("D6A45F"),
            onAccent: .hex("2A2012"), border: .hex("51463C")),
    ]

    static let style: [ThemeName: ThemeStyle] = [
        .warmPaper: ThemeStyle(label: "暖纸", feeling: "下午桌上的一张纸"),
        .duskGarden: ThemeStyle(label: "黄昏花园", feeling: "太阳落下前的 20 分钟"),
        .minimalIos: ThemeStyle(label: "极简", feeling: "干净、留白、不催促"),
        .fieldNotebook: ThemeStyle(label: "野外笔记", feeling: "坐在草地边写一句话"),
        .softRitual: ThemeStyle(label: "睡前仪式", feeling: "温水、台灯、不补救人生"),
    ]

    static let order: [ThemeName] = [.warmPaper, .duskGarden, .minimalIos, .fieldNotebook, .softRitual]

    static func tokens(for name: ThemeName) -> ThemeTokens {
        tokens[name] ?? tokens[.warmPaper]!
    }
}

// MARK: - Design constants

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let card: CGFloat = 24
    static let button: CGFloat = 999
    static let sheet: CGFloat = 32
}

// MARK: - Color from hex

extension Color {
    static func hex(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Environment plumbing

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.tokens(for: .warmPaper)
}

extension EnvironmentValues {
    var theme: ThemeTokens {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
