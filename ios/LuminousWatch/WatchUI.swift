//
//  WatchUI.swift
//  Luminous Watch App
//
//  Watch-native UI over the shared core. The same gentle loop as iOS —
//  Now Opportunity → Complete / Partial → Daily Trace — sized for the wrist.
//  The skin (glass / ocean / paper) is switchable here too, tinting the field.
//

import SwiftUI

// MARK: - Skin tint (light-weight backdrop, no Canvas/MeshGradient on the wrist)

/// A soft gradient per skin, so switching the skin visibly re-skins the watch.
func watchSkinGradient(_ aesthetic: Aesthetic) -> LinearGradient {
    let colors: [Color]
    switch aesthetic {
    case .glass: colors = [Color(red: 0.10, green: 0.13, blue: 0.20), Color(red: 0.05, green: 0.06, blue: 0.10)]
    case .ocean: colors = [Color(red: 0.03, green: 0.16, blue: 0.27), Color(red: 0.01, green: 0.07, blue: 0.14)]
    case .paper: colors = [Color(red: 0.20, green: 0.17, blue: 0.12), Color(red: 0.10, green: 0.08, blue: 0.05)]
    }
    return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
}

// MARK: - Root

struct WatchRootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        WatchNowView()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Copy.Home.primary)
                                .font(.system(size: 17, weight: .semibold))
                            Text(Copy.Home.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(Copy.appTitle).font(.system(size: 12))
                }

                Section {
                    NavigationLink {
                        WatchTracesView()
                    } label: {
                        Label(traceLabel, systemImage: "book")
                            .font(.system(size: 15))
                    }
                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        Label("外观风格", systemImage: "paintpalette")
                            .font(.system(size: 15))
                    }
                }
            }
            .navigationTitle("今天")
            .containerBackground(watchSkinGradient(store.aesthetic), for: .navigation)
        }
    }

    private var traceLabel: String {
        let n = store.tracesForToday().count
        return n == 0 ? "今天的痕迹" : "今天的痕迹 · \(n)"
    }
}

// MARK: - Now

struct WatchNowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var opps: [Opportunity] = []
    @State private var index = 0
    @State private var resultText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let resultText {
                    doneCard(resultText)
                } else if opps.isEmpty {
                    Text("\(Copy.Now.noneTitle)\n\(Copy.Now.noneBody)")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                } else {
                    opportunityCard
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("现在")
        .containerBackground(watchSkinGradient(store.aesthetic), for: .navigation)
        .onAppear(perform: load)
    }

    @ViewBuilder private var opportunityCard: some View {
        let o = opps[index]
        if let seed = store.findSeed(o.seedId) {
            VStack(alignment: .leading, spacing: 8) {
                Text(seed.title)
                    .font(.system(size: 18, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(o.suggestedAction.isEmpty ? seed.minimumAction : o.suggestedAction)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button { complete(.completed) } label: {
                    Text(Copy.Completion.done).frame(maxWidth: .infinity)
                }
                .tint(.green)
                Button { complete(.partial) } label: {
                    Text(Copy.Completion.partial).frame(maxWidth: .infinity)
                }
                Button { complete(.skipped) } label: {
                    Text(Copy.Completion.skipped).frame(maxWidth: .infinity)
                }
                .tint(.secondary)

                if opps.count > 1 {
                    Button { index = (index + 1) % opps.count } label: {
                        Label(Copy.Now.orAlso, systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func doneCard(_ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
            Text(text)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("好") { dismiss() }
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 14)
    }

    private func load() {
        let ctx = ContextBuilder.build(ContextInput(
            mood: store.lastPick.mood ?? .okay,
            energy: store.lastPick.energy ?? .medium,
            isMobile: true
        ))
        opps = Scoring.recommend(store.seeds, ctx, limit: 3)
        index = 0
    }

    private func complete(_ kind: CompletionKind) {
        Feedback.completion(kind)
        let o = opps[index]
        let seed = store.findSeed(o.seedId)
        if kind == .skipped {
            resultText = Copy.Completion.skippedMsg
            return
        }
        let trace = TraceGenerator.buildTrace(seed, kind, opportunityId: o.id)
        store.addTrace(trace)
        if let seed, kind == .completed {
            store.setSeedStatus(seed.id, .sleeping)
        }
        resultText = trace.text
    }
}

// MARK: - Traces

struct WatchTracesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            let today = store.tracesForToday()
            if today.isEmpty {
                Text(Copy.Home.traceEmpty)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(today) { trace in
                    Text(trace.text)
                        .font(.system(size: 14))
                        .lineSpacing(2)
                        .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("痕迹")
        .containerBackground(watchSkinGradient(store.aesthetic), for: .navigation)
    }
}

// MARK: - Settings (skin picker — switchable on the wrist too)

struct WatchSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section {
                ForEach(Aesthetic.allCases) { skin in
                    Button { store.setAesthetic(skin) } label: {
                        HStack {
                            Image(systemName: skin.symbol)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(skin.label).font(.system(size: 15, weight: .medium))
                                Text(skin.feeling).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.aesthetic == skin {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("外观风格").font(.system(size: 12))
            }
        }
        .navigationTitle("外观")
        .containerBackground(watchSkinGradient(store.aesthetic), for: .navigation)
    }
}
