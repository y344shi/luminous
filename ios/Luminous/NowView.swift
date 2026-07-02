//
//  NowView.swift
//  Luminous
//
//  The "现在别消失" flow: context → opportunities → completion → trace.
//  Ported from components/opportunity/NowFlow.tsx.
//

import SwiftUI

/// App-level navigation shared across tabs (for cross-tab jumps).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
}

enum AppTab: Hashable {
    case today, seeds, traces, settings
}

struct NowView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme
    @Binding var path: NavigationPath

    private enum Step { case context, list, completion, trace }

    @State private var step: Step = .context
    @State private var mood: Mood?
    @State private var energy: Energy?
    @State private var freeMinutes: Int?
    @State private var freeTouched = false
    @State private var locationHint: LocationType?
    @State private var weatherGood = false

    @State private var opps: [Opportunity] = []
    @State private var activeIndex = 0
    @State private var chosen: Opportunity?
    @State private var traceText = ""
    @State private var savedTraceId: String?
    @State private var editing = false
    @State private var draftText = ""

    private var isLateNight: Bool {
        TimeOfDay.isLateNight(hour: Calendar.current.component(.hour, from: Date()))
    }
    private var ready: Bool { mood != nil && energy != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                switch step {
                case .context: contextStep
                case .list: listStep
                case .completion: completionStep
                case .trace: traceStep
                }
            }
            .padding(Spacing.lg)
        }
        .themedScreen()
        .navigationTitle(Copy.Home.primary)
        .inlineNavTitle()
        .onAppear {
            if mood == nil { mood = store.lastPick.mood }
            if energy == nil { energy = store.lastPick.energy }
        }
    }

    // MARK: Step 1 — context

    private var contextStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if isLateNight {
                BreathingCard(soft: true) {
                    Text(Copy.LateNight.body)
                        .font(.system(size: 14)).lineSpacing(4)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            question(Copy.Now.moodQuestion)
            ChipGroup(options: Pickers.mood, isActive: { $0 == mood }) { mood = $0 }

            question(Copy.Now.energyQuestion)
            ChipGroup(options: Pickers.energy, isActive: { $0 == energy }) { energy = $0 }

            question(Copy.Now.freeQuestion)
            ChipGroup(options: Pickers.free, isActive: { v in freeTouched && v == freeMinutes }) {
                freeMinutes = $0; freeTouched = true
            }

            question(Copy.Now.placeQuestion)
            ChipGroup(options: Pickers.location, isActive: { $0 == locationHint }) { v in
                locationHint = (locationHint == v) ? nil : v
            }
            if locationHint == .outdoor || locationHint == .downtown {
                Chip(label: Copy.Now.weatherLabel, active: weatherGood) { weatherGood.toggle() }
            }

            SoftButton(title: Copy.Now.findButton, enabled: ready) { handleFind() }
                .padding(.top, Spacing.sm)
        }
    }

    private func question(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func handleFind() {
        guard let mood = mood, let energy = energy else { return }
        store.rememberPick(mood, energy)
        // Stated answers + everything the device can sense right now.
        var input = ContextInput(
            mood: mood, energy: energy,
            freeMinutes: freeTouched ? freeMinutes : nil,
            locationHint: locationHint ?? sensed.locationHint,
            isOutdoorWeatherGood: weatherGood ? true : sensed.isOutdoorWeatherGood,
            isAtComputer: locationHint == .computer
        )
        input.activity = sensed.activity
        input.weatherKind = sensed.weatherKind
        input.nearbyKinds = isLateNight ? [] : sensed.nearbyKinds
        let ctx = ContextBuilder.build(input)
        let result = Scoring.recommend(store.seeds, ctx, limit: 3)
        opps = result
        activeIndex = 0
        store.setOpportunities(result, ctx)
        step = .list
    }

    // MARK: Step 2 — list

    @ViewBuilder private var listStep: some View {
        if opps.isEmpty {
            EmptyState(
                icon: "🍃",
                text: "\(Copy.Now.noneTitle)\n\(Copy.Now.noneBody)",
                actionLabel: Copy.Now.plantNew
            ) { path.append(Route.add) }
        } else {
            let o = opps[activeIndex]
            if let seed = store.findSeed(o.seedId) {
                OpportunityCard(
                    opportunity: o, seed: seed,
                    canSwap: opps.count > 1,
                    onStart: { chosen = o; step = .completion },
                    onSwap: { activeIndex = (activeIndex + 1) % max(opps.count, 1) },
                    onLater: { traceText = ""; savedTraceId = nil; step = .trace }
                )
            }
            let peeks = opps.enumerated().filter { $0.offset != activeIndex }
            if !peeks.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(Copy.Now.orAlso)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                    FlowLayout(spacing: Spacing.sm) {
                        ForEach(peeks, id: \.element.id) { item in
                            if let s = store.findSeed(item.element.seedId) {
                                Button { activeIndex = item.offset } label: {
                                    Text(s.title)
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .foregroundStyle(theme.textSecondary)
                                        .background(theme.surface)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(theme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Step 3 — completion

    private var completionStep: some View {
        BreathingCard {
            VStack(spacing: Spacing.md) {
                Text(Copy.Completion.prompt)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textPrimary)
                SoftButton(title: Copy.Completion.done) { complete(.completed) }
                SoftButton(title: Copy.Completion.partial, variant: .soft) { complete(.partial) }
                SoftButton(title: Copy.Completion.skipped, variant: .ghost) { complete(.skipped) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func complete(_ kind: CompletionKind) {
        Feedback.completion(kind)
        let seed = store.findSeed(chosen?.seedId)
        if kind == .skipped {
            traceText = Copy.Completion.skippedMsg
            savedTraceId = nil
            step = .trace
            return
        }
        let trace = TraceGenerator.buildTrace(seed, kind, opportunityId: chosen?.id)
        store.addTrace(trace)
        if let seed = seed, kind == .completed {
            store.setSeedStatus(seed.id, .sleeping)
        }
        traceText = trace.text
        savedTraceId = trace.id
        step = .trace
    }

    // MARK: Step 4 — trace

    private var traceStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if editing {
                BreathingCard {
                    VStack(spacing: Spacing.sm) {
                        TextEditor(text: $draftText)
                            .font(.system(size: 16))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(theme.surfaceSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        HStack(spacing: Spacing.sm) {
                            SoftButton(title: Copy.Traces.editSave, enabled: !draftText.trimmed.isEmpty) {
                                saveEdited()
                            }
                            SoftButton(title: "取消", variant: .ghost) { editing = false }
                        }
                    }
                }
            } else {
                BreathingCard {
                    Text(traceText.isEmpty ? "\(Copy.Now.later)。\n愿望还在，等下一个契机。" : traceText)
                        .font(.system(size: 18)).lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .foregroundStyle(theme.textPrimary)
                }

                if savedTraceId == nil && traceText.isEmpty {
                    SoftButton(title: Copy.Now.recordRest, variant: .soft) {
                        let trace = TraceGenerator.buildRestTrace()
                        store.addTrace(trace)
                        traceText = trace.text
                        savedTraceId = trace.id
                    }
                }
                if savedTraceId != nil {
                    Button {
                        draftText = traceText; editing = true
                    } label: {
                        Text(Copy.Traces.edit)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                SoftButton(title: Copy.Now.backToToday) { path = NavigationPath() }
                SoftButton(title: Copy.Now.seeTraces, variant: .ghost) {
                    path = NavigationPath()
                    router.selectedTab = .traces
                }
            }
        }
    }

    private func saveEdited() {
        let text = draftText.trimmed
        if let id = savedTraceId, !text.isEmpty {
            store.updateTrace(id, text: text)
            traceText = text
        }
        editing = false
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
