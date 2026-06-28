//
//  LuminousWatchApp.swift
//  Luminous Watch App
//
//  The watchOS entry point. Shares the whole core (Domain / Store / Scoring /
//  SeedParser / SemanticTime / Theme / Copy / DayGrade / Feedback / Aesthetic)
//  with the iOS + macOS app — only the views are watch-native (see WatchUI).
//

import SwiftUI

@main
struct LuminousWatchApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
        }
    }
}
