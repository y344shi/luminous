//
//  VoicePrefs.swift
//  Luminous — pick which voice reads each language.
//
//  iOS ships several voices per language (default / enhanced / premium, different
//  speakers/tones). This stores the user's chosen voice per language (by the
//  voice's stable identifier, in UserDefaults) so playback uses it everywhere.
//  The Speaker consults this before falling back to the system default.
//

import Foundation
import AVFoundation

enum VoicePrefs {
    /// The languages we offer a voice choice for (a curated, common set); only
    /// those with at least one installed voice are actually shown in Settings.
    static let offered: [(code: String, name: String)] = [
        ("fr", "法语 · Français"),
        ("en", "英语 · English"),
        ("zh", "中文"),
        ("es", "西班牙语 · Español"),
        ("de", "德语 · Deutsch"),
        ("it", "意大利语 · Italiano"),
        ("ja", "日语 · 日本語"),
        ("ko", "韩语 · 한국어"),
    ]

    static func lang2(_ code: String) -> String { String(code.prefix(2)).lowercased() }
    private static func key(_ code: String) -> String { "tdd.voice.\(lang2(code))" }

    static func selectedIdentifier(for code: String) -> String? {
        UserDefaults.standard.string(forKey: key(code))
    }

    static func setIdentifier(_ id: String?, for code: String) {
        let k = key(code)
        if let id { UserDefaults.standard.set(id, forKey: k) }
        else { UserDefaults.standard.removeObject(forKey: k) }
    }

    /// Installed voices for a language, best quality first (enhanced/premium),
    /// then alphabetical — a stable, human order for the picker.
    static func voices(for code: String) -> [AVSpeechSynthesisVoice] {
        let p = lang2(code)
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(p) }
            .sorted { a, b in
                if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
                return a.name < b.name
            }
    }

    /// Only the offered languages that have ≥1 installed voice.
    static func availableLanguages() -> [(code: String, name: String)] {
        offered.filter { !voices(for: $0.code).isEmpty }
    }

    /// A short human label for a voice: name + region + quality hint.
    static func label(for v: AVSpeechSynthesisVoice) -> String {
        let q: String
        switch v.quality {
        case .premium: q = " · 高级"
        case .enhanced: q = " · 增强"
        default: q = ""
        }
        return "\(v.name) (\(v.language))\(q)"
    }
}
