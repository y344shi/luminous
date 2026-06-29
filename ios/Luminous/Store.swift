//
//  Store.swift
//  Luminous
//
//  The single stateful glue: an @Observable store backed by UserDefaults
//  (the iOS analogue of the web app's localStorage). Ported from
//  lib/store.ts + lib/storage.ts. Every persisted write goes through `save…`.
//

import Foundation
import Observation

struct LastPick: Codable {
    var mood: Mood?
    var energy: Energy?
}

@Observable
final class AppStore {

    // MARK: Persistence keys (kept parallel to the web app's tdd.* keys)
    private enum Key {
        static let seeds = "tdd.seeds"
        static let traces = "tdd.traces"
        static let settings = "tdd.settings"
        static let samplesPlanted = "tdd.samplesPlanted"
        static let lastPick = "tdd.lastPick"
        static let introSeen = "tdd.introSeen"
        static let aesthetic = "tdd.aesthetic"
        static let aestheticAuto = "tdd.aestheticAuto"
        static let senseAround = "tdd.senseAround"
        static let all = [seeds, traces, settings, samplesPlanted, lastPick, introSeen, aesthetic, aestheticAuto, senseAround]
    }

    // MARK: Persisted state
    var seeds: [Seed] = []
    var traces: [DailyTrace] = []
    var settings: Settings = .default
    var samplesPlanted = false
    var lastPick = LastPick()
    var introSeen = false

    /// The active visual skin (glass / ocean / paper). Persisted; drives
    /// `AestheticField` so switching it in Settings re-skins the app live.
    var aesthetic: Aesthetic = .fallback

    /// When true the skin follows the system appearance instead of `aesthetic`:
    /// Dark Mode → glass, Light Mode → paper. Persisted.
    var aestheticAuto: Bool = false

    /// Opt-in to sensing the surroundings (location → weather; mic/HR later).
    /// Motion is permission-free and always on; this gates the rest. Persisted.
    var senseAround: Bool = false

    // MARK: Transient state (not persisted)
    var opportunities: [Opportunity] = []
    var lastContext: ContextSnapshot?

    private let defaults: UserDefaults
    private let maxTraces = 500

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hydrate()
    }

    var theme: ThemeName { settings.theme }
    var themeTokens: ThemeTokens { Theme.tokens(for: settings.theme) }

    // MARK: - Hydration

    private func hydrate() {
        seeds = load([Seed].self, Key.seeds) ?? []
        traces = load([DailyTrace].self, Key.traces) ?? []
        settings = load(Settings.self, Key.settings) ?? .default
        samplesPlanted = defaults.bool(forKey: Key.samplesPlanted)
        lastPick = load(LastPick.self, Key.lastPick) ?? LastPick()
        introSeen = defaults.bool(forKey: Key.introSeen)
        aesthetic = defaults.string(forKey: Key.aesthetic)
            .flatMap(Aesthetic.init(rawValue:)) ?? .fallback
        aestheticAuto = defaults.bool(forKey: Key.aestheticAuto)
        senseAround = defaults.bool(forKey: Key.senseAround)

        // First run: plant a small mock garden so the app never feels empty.
        if seeds.isEmpty && traces.isEmpty {
            seeds = MockGarden.seed()
            save(seeds, Key.seeds)
            samplesPlanted = true
            defaults.set(true, forKey: Key.samplesPlanted)
        }
    }

    // MARK: - Seeds

    func addSeed(_ seed: Seed) {
        seeds.insert(seed, at: 0)
        save(seeds, Key.seeds)
        if samplesPlanted {
            samplesPlanted = false
            defaults.set(false, forKey: Key.samplesPlanted)
        }
    }

    func updateSeed(_ id: String, _ mutate: (inout Seed) -> Void) {
        guard let idx = seeds.firstIndex(where: { $0.id == id }) else { return }
        mutate(&seeds[idx])
        seeds[idx].updatedAt = DomainUtil.nowIso()
        save(seeds, Key.seeds)
    }

    func setSeedStatus(_ id: String, _ status: SeedStatus) {
        updateSeed(id) { $0.status = status }
    }

    func findSeed(_ id: String?) -> Seed? {
        guard let id = id else { return nil }
        return seeds.first { $0.id == id }
    }

    /// Recently-touched seeds for the Home preview (active/sleeping only).
    var recentSeeds: [Seed] {
        seeds.filter { $0.status == .active || $0.status == .sleeping }
    }

    // MARK: - Traces

    func addTrace(_ trace: DailyTrace) {
        traces.insert(trace, at: 0)
        if traces.count > maxTraces { traces = Array(traces.prefix(maxTraces)) }
        save(traces, Key.traces)
    }

    func updateTrace(_ id: String, text: String) {
        guard let idx = traces.firstIndex(where: { $0.id == id }) else { return }
        traces[idx].text = text
        save(traces, Key.traces)
    }

    func removeTrace(_ id: String) {
        traces.removeAll { $0.id == id }
        save(traces, Key.traces)
    }

    func tracesForToday() -> [DailyTrace] {
        let today = DomainUtil.localDateKey()
        return traces.filter { $0.date == today }
    }

    // MARK: - Opportunities (transient)

    func setOpportunities(_ opps: [Opportunity], _ ctx: ContextSnapshot) {
        opportunities = opps
        lastContext = ctx
    }

    func rememberPick(_ mood: Mood, _ energy: Energy) {
        lastPick = LastPick(mood: mood, energy: energy)
        save(lastPick, Key.lastPick)
    }

    // MARK: - Settings

    func setTheme(_ theme: ThemeName) {
        settings.theme = theme
        save(settings, Key.settings)
    }

    func updateSettings(_ mutate: (inout Settings) -> Void) {
        mutate(&settings)
        save(settings, Key.settings)
    }

    /// Switch the visual skin and persist it. Picking a skin by hand turns off
    /// auto (follow-system) mode. Re-skins the app immediately.
    func setAesthetic(_ a: Aesthetic) {
        aesthetic = a
        aestheticAuto = false
        defaults.set(a.rawValue, forKey: Key.aesthetic)
        defaults.set(false, forKey: Key.aestheticAuto)
    }

    /// Turn follow-system (Dark → glass / Light → paper) on or off. Persisted.
    func setAestheticAuto(_ on: Bool) {
        aestheticAuto = on
        defaults.set(on, forKey: Key.aestheticAuto)
    }

    /// Opt in / out of sensing the surroundings. Persisted.
    func setSenseAround(_ on: Bool) {
        senseAround = on
        defaults.set(on, forKey: Key.senseAround)
    }

    /// The skin to actually render. In auto mode it follows the system
    /// appearance; otherwise it's the user's chosen `aesthetic`.
    func effectiveAesthetic(dark: Bool) -> Aesthetic {
        aestheticAuto ? (dark ? .glass : .paper) : aesthetic
    }

    func dismissSamplesNote() {
        samplesPlanted = false
        defaults.set(false, forKey: Key.samplesPlanted)
    }

    func dismissIntro() {
        introSeen = true
        defaults.set(true, forKey: Key.introSeen)
    }

    func resetAll() {
        Key.all.forEach { defaults.removeObject(forKey: $0) }
        seeds = MockGarden.seed()
        save(seeds, Key.seeds)
        samplesPlanted = true
        defaults.set(true, forKey: Key.samplesPlanted)
        traces = []
        settings = .default
        lastPick = LastPick()
        introSeen = false
        aesthetic = .fallback
        aestheticAuto = false
        senseAround = false
        opportunities = []
        lastContext = nil
    }

    // MARK: - JSON helpers

    private func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
