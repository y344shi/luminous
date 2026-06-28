//
//  HomeView.swift
//  Luminous
//
//  The "今天" tab — the warm entry point. One primary action: 现在别消失.
//  Ported from app/page.tsx + the home components.
//

import SwiftUI

/// Navigation routes used across the Home stack.
enum Route: Hashable {
    case now
    case add
    case seedDetail(String)
}

/// A small row of category / duration / energy descriptors shared by cards.
struct SeedMetaRow: View {
    @Environment(\.theme) private var theme
    let seed: Seed

    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(seed.categories, id: \.self) { cat in
                if let meta = Meta.category[cat] {
                    pill("\(meta.emoji) \(meta.label)")
                }
            }
            pill(Meta.durationLabel(seed.estimatedDurationMin))
            pill(Meta.energyLabel[seed.energyRequired] ?? "")
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(theme.textMuted)
            .background(theme.surfaceSoft)
            .clipShape(Capsule())
    }
}

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var path = NavigationPath()

    private var isLateNight: Bool {
        TimeOfDay.isLateNight(hour: Calendar.current.component(.hour, from: Date()))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if isLateNight { lateNightCard }

                    SoftButton(title: Copy.Home.primary) { path.append(Route.now) }

                    Button { path.append(Route.add) } label: {
                        Text(Copy.Home.addSeed)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    traceSection
                    seedsSection
                }
                .padding(Spacing.lg)
            }
            .background(AestheticField().ignoresSafeArea())
            .hiddenNavBar()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .now: NowView(path: $path)
                case .add: AddSeedView(path: $path)
                case .seedDetail(let id): SeedDetailView(seedId: id)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(Copy.appTitle)
                .font(.system(size: 15))
                .foregroundStyle(theme.textMuted)
            Text(Copy.Home.question)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(Copy.Home.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(DayGrade.line(hour: Calendar.current.component(.hour, from: Date())))
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(theme.textMuted)
                .padding(.top, Spacing.xs)
        }
        .padding(.top, Spacing.sm)
    }

    private var lateNightCard: some View {
        BreathingCard(soft: true) {
            Text(Copy.LateNight.body)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var traceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(Copy.Home.traceHeading)
                .font(.system(size: 13))
                .foregroundStyle(theme.textMuted)
            let today = store.tracesForToday()
            if today.isEmpty {
                BreathingCard {
                    Text(Copy.Home.traceEmpty)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                ForEach(today.prefix(2)) { trace in
                    BreathingCard {
                        Text(trace.text)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
    }

    private var seedsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(Copy.Home.seedsHeading)
                .font(.system(size: 13))
                .foregroundStyle(theme.textMuted)
            let recent = store.recentSeeds.prefix(3)
            if recent.isEmpty {
                Text(Copy.Home.seedsEmpty)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(Array(recent)) { seed in
                    Button { path.append(Route.seedDetail(seed.id)) } label: {
                        BreathingCard {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(seed.title)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)
                                SeedMetaRow(seed: seed)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
