//
//  PlanView.swift
//  Luminous — the plan section of a wish card: tiny steps, live resources
//
//  "帮我把它拆小" → the model (or the fallback) hands back 2–4 steps. A step
//  with a resource shows it inline: a fitting nearby place with a real walking
//  route (Maps), a themed vocab set grown from where the day is, the camera
//  translator, or the breath script. Everything is an offer.
//

import SwiftUI
import MapKit

struct PlanSectionView: View {
    let seed: Seed
    var onPhoto: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme

    @State private var loading = false
    @State private var steps: [PlanStep] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if steps.isEmpty {
                Button { run() } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.small) }
                        else { Image(systemName: "square.stack.3d.up") }
                        Text(loading ? "在把它拆小…" : "帮我把它拆小")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.accentSoft)
                    .foregroundStyle(theme.accentText)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(loading)
            } else {
                Text("一步一步来，从最容易的开始")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
                ForEach(steps) { step in
                    PlanStepRow(seed: seed, step: step, onPhoto: onPhoto)
                }
            }
        }
    }

    private func run() {
        loading = true
        let hour = Calendar.current.component(.hour, from: Date())
        var bits = [DayGrade.line(hour: hour)]
        if let w = sensed.weatherKind { bits.append("天气 \(w.rawValue)") }
        if !sensed.nearbyKinds.isEmpty {
            bits.append("附近有 " + sensed.nearbyKinds.map(\.rawValue).joined(separator: ","))
        }
        let line = bits.joined(separator: "；")
        Task {
            let plan = await TaskPlanner.plan(for: seed, contextLine: line)
            await MainActor.run {
                steps = plan
                loading = false
                store.logEvent(kind: "plan.made", payload: seed.id)
            }
        }
    }
}

// MARK: - One step + its resource

private struct PlanStepRow: View {
    let seed: Seed
    let step: PlanStep
    var onPhoto: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme

    @State private var walk: RouteFinder.Walk?
    @State private var vocabLoading = false
    @State private var vocab: [VocabItem] = []
    @State private var breathOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
                    .frame(width: 18)
                Text(step.title)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            resourceView
                .padding(.leading, 26)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var icon: String {
        switch step.resource {
        case .route: return "figure.walk"
        case .vocab: return "character.book.closed"
        case .photo: return "text.viewfinder"
        case .breath: return "wind"
        case .none: return "circle.dotted"
        }
    }

    @ViewBuilder private var resourceView: some View {
        switch step.resource {
        case .route: routeResource
        case .vocab: vocabResource
        case .photo:
            Button { onPhoto() } label: {
                chip("打开拍照翻译", system: "camera.fill")
            }.buttonStyle(.plain)
        case .breath:
            Button { withAnimation { breathOpen.toggle() } } label: {
                chip(breathOpen ? "一 吸四秒 · 二 停两秒 · 三 呼六秒" : "展开呼吸引导",
                     system: "wind")
            }.buttonStyle(.plain)
        case .none: EmptyView()
        }
    }

    // A fitting nearby place + a real walking route.
    @ViewBuilder private var routeResource: some View {
        if let place = fittingPlace {
            Button { place.mapItem.openInMaps() } label: {
                chip("\(place.emoji) \(place.name) · \(walk?.label ?? place.distanceLabel)",
                     system: "map")
            }
            .buttonStyle(.plain)
            .task {
                walk = await RouteFinder.walking(to: place.mapItem, from: sensed.coordinate)
            }
        } else {
            Text("附近暂时没有合适的地方，家里也很好。")
                .font(.system(size: 12)).foregroundStyle(theme.textMuted)
        }
    }

    private var fittingPlace: NearbyPlace? {
        var kinds = Set<PlaceKind>()
        for c in seed.categories { if let a = Scoring.placeAffinity[c] { kinds.formUnion(a) } }
        if kinds.isEmpty { kinds = [.park, .cafe] }
        return sensed.nearby.first { p in p.kind.map { kinds.contains($0) } ?? false }
    }

    // A themed vocab set — the theme comes from the step's detail.
    @ViewBuilder private var vocabResource: some View {
        if !vocab.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vocab) { v in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(v.word).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(v.meaning).font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        } else if AIHelper.isAvailable {
            Button { runVocab() } label: {
                chip(vocabLoading ? "在挑词…" : "挑几个「\(theme_)」的词",
                     system: "sparkles")
            }
            .buttonStyle(.plain)
            .disabled(vocabLoading)
        }
    }

    private var theme_: String {
        if !step.detail.isEmpty { return step.detail }
        let hour = Calendar.current.component(.hour, from: Date())
        return LanguageScenarios.options(nearby: sensed.nearbyKinds,
                                         activity: sensed.activity,
                                         hour: hour).first ?? "日常寒暄"
    }

    private func runVocab() {
        let lang = LearningTopic.language(ofTitle: seed.title) ?? "法语"
        vocabLoading = true
        let learned = store.learnedWords(lang)
        let theme = theme_
        Task {
            let words = (try? await AIHelper.vocab(
                language: lang, learned: learned,
                context: "主题：\(theme)")) ?? []
            await MainActor.run {
                vocab = words
                vocabLoading = false
                if !words.isEmpty {
                    store.logLearning(LearningEntry(kind: .vocab, language: lang,
                                                    items: words.map(\.word),
                                                    note: "主题：\(theme)"))
                }
            }
        }
    }

    private func chip(_ text: String, system: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 11))
            Text(text).font(.system(size: 12, weight: .medium)).lineLimit(2)
        }
        .foregroundStyle(theme.accentText)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(theme.accentSoft)
        .clipShape(Capsule())
    }
}
