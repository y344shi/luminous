//
//  RootView.swift
//  Luminous
//
//  The app shell: 4 tabs (今天 / 愿望 / 痕迹 / 设置) + theme propagation.
//  Ported from components/layout/{AppShell,BottomNav}.tsx.
//

import SwiftUI

struct RootView: View {
    @State private var store = AppStore()
    @State private var router = AppRouter()
    @State private var sensed = SensedSignals()
    @State private var music = SkinMusic()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private func updateMusic() {
        music.update(aesthetic: store.effectiveAesthetic(dark: colorScheme == .dark), on: store.musicOn)
    }

    /// Leaving the app while a wish is ripe → one soft reminder at that wish's
    /// natural hour (or +2h). The gate enforces off-by-default, quiet hours,
    /// the daily cap and the late-night rule; returning cancels it.
    private func scheduleGentleNudgeIfRipe() {
        guard store.settings.nudgesEnabled,
              let top = store.opportunities.first,
              let seed = store.findSeed(top.seedId) else { return }
        let stats = store.seedHistory()[seed.id]
        let hour = stats?.modalDoneTime.map(Self.hourFor) ?? nil
        let cal = Calendar.current
        var at = Date().addingTimeInterval(2 * 3600)
        if let hour {
            var target = cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
            if target <= Date() { target = cal.date(byAdding: .day, value: 1, to: target)! }
            at = min(at, target) == at && target.timeIntervalSinceNow < 12 * 3600 ? target : at
        }
        Nudger.shared.schedule(
            title: seed.title,
            body: "\(seed.minimumAction)。愿望还在，等一个刚好的时候。",
            at: at,
            settings: store.settings)
    }

    private static func hourFor(_ t: SemanticTime) -> Int {
        switch t {
        case .morning: return 9;  case .lunch: return 12
        case .afternoon: return 15; case .afterWork: return 18
        case .evening: return 20; case .weekend: return 15
        case .lateNight, .transit: return 20
        }
    }

    var body: some View {
        @Bindable var router = router
        let tokens = store.themeTokens

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label(Copy.Tab.today, systemImage: "sun.max") }
                .tag(AppTab.today)
            GardenView()
                .tabItem { Label(Copy.Tab.seeds, systemImage: "leaf") }
                .tag(AppTab.seeds)
            TracesView()
                .tabItem { Label(Copy.Tab.traces, systemImage: "book") }
                .tag(AppTab.traces)
            SettingsView()
                .tabItem { Label(Copy.Tab.settings, systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(tokens.accentText)
        .environment(store)
        .environment(router)
        .environment(sensed)
        .environment(\.theme, tokens)
        .task {
            sensed.start(enabled: store.senseAround); updateMusic()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demoStars"),
               store.traces.count < 5 {
                DemoSky.plant(into: store)
            }
            #endif
        }
        .onChange(of: store.senseAround) { _, on in sensed.start(enabled: on) }
        // Coming back to the app is a moment worth re-sensing — and it
        // dissolves any pending nudge (you're already here). Leaving with a
        // ripe wish may schedule ONE soft, gate-checked reminder.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                sensed.refresh()
                Nudger.shared.cancelPending()
            case .background:
                scheduleGentleNudgeIfRipe()
            default: break
            }
        }
        // Sensed transitions feed the life-event log (rhythm/recurrence substrate).
        .onChange(of: sensed.activity) { _, a in
            if let a { store.logEvent(kind: "sense.activity", payload: a.rawValue) }
        }
        .onChange(of: sensed.weatherKind) { _, w in
            if let w { store.logEvent(kind: "sense.weather", payload: w.rawValue) }
        }
        .onChange(of: sensed.nearbyKinds) { old, new in
            let entered = Set(new).subtracting(old)
            if !entered.isEmpty {
                store.logEvent(kind: "sense.place",
                               payload: entered.map(\.rawValue).sorted().joined(separator: ","))
            }
        }
        // Each coarse cell fix teaches the app where home/work are (on-device).
        .onChange(of: sensed.currentCell) { _, cell in
            guard let cell else { return }
            store.logEvent(kind: "sense.cell", payload: cell)
            let learned = store.learnedPlaceCells()
            sensed.homeCell = learned.home
            sensed.workCell = learned.work
        }
        .onChange(of: store.musicOn) { _, _ in updateMusic() }
        .onChange(of: store.aesthetic) { _, _ in updateMusic() }
        .onChange(of: store.aestheticAuto) { _, _ in updateMusic() }
        .onChange(of: colorScheme) { _, _ in updateMusic() }
        // In auto-skin mode we follow the system appearance (so the skin can
        // track Dark/Light); otherwise the theme drives the color scheme.
        .preferredColorScheme(store.aestheticAuto ? nil : (store.theme == .softRitual ? .dark : .light))
    }
}

#Preview {
    RootView()
}
