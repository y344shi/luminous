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

    private func updateMusic() {
        music.update(aesthetic: store.effectiveAesthetic(dark: colorScheme == .dark), on: store.musicOn)
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
        .task { sensed.start(enabled: store.senseAround); updateMusic() }
        .onChange(of: store.senseAround) { _, on in sensed.start(enabled: on) }
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
