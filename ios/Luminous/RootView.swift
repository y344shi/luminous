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
        .environment(\.theme, tokens)
        // In auto-skin mode we follow the system appearance (so the skin can
        // track Dark/Light); otherwise the theme drives the color scheme.
        .preferredColorScheme(store.aestheticAuto ? nil : (store.theme == .softRitual ? .dark : .light))
    }
}

#Preview {
    RootView()
}
