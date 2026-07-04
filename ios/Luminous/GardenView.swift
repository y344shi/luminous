//
//  GardenView.swift
//  Luminous
//
//  The "愿望" tab — the seed garden + a light seed detail.
//  Ported from components/seed/SeedGarden.tsx and SeedDetail.tsx.
//

import SwiftUI

struct GardenView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var path = NavigationPath()

    private var visibleSeeds: [Seed] {
        store.seeds.filter { $0.status != .completed }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    PageHeader(title: Copy.Garden.title, subtitle: Copy.Garden.subtitle)

                    if store.samplesPlanted {
                        sampleNote
                    }

                    if visibleSeeds.isEmpty {
                        EmptyState(icon: "🌱", text: Copy.Garden.empty, actionLabel: Copy.Home.addSeed) {
                            path.append(Route.add)
                        }
                    } else {
                        ForEach(visibleSeeds) { seed in
                            Button { path.append(Route.seedDetail(seed.id)) } label: {
                                seedCard(seed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle(Copy.Tab.seeds)
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { path.append(Route.add) } label: {
                        Image(systemName: "plus")
                    }
                    .tint(theme.accentText)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .add: AddSeedView(path: $path)
                case .seedDetail(let id): SeedDetailView(seedId: id)
                case .now: EmptyView()
                }
            }
        }
    }

    private var sampleNote: some View {
        BreathingCard(soft: true) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(Copy.Garden.sampleNote)
                    .font(.system(size: 14)).lineSpacing(3)
                    .foregroundStyle(theme.textSecondary)
                Button(Copy.Garden.sampleNoteDismiss) { store.dismissSamplesNote() }
                    .font(.system(size: 13))
                    .tint(theme.accentText)
            }
        }
    }

    private func seedCard(_ seed: Seed) -> some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(seed.title)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if seed.status == .sleeping {
                        statusPill(Copy.SeedDetail.statusSleeping)
                    } else if seed.status == .archived {
                        statusPill(Copy.SeedDetail.statusArchived)
                    }
                }
                SeedMetaRow(seed: seed)
            }
        }
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(theme.textMuted)
            .background(theme.surfaceSoft)
            .clipShape(Capsule())
    }
}

// MARK: - Seed detail

struct SeedDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let seedId: String

    private var seed: Seed? { store.findSeed(seedId) }

    var body: some View {
        ScrollView {
            if let seed = seed {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(statusText(seed.status))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textMuted)

                    Text(seed.title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let desc = seed.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15)).lineSpacing(4)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let tags = seed.tags, !tags.isEmpty {
                        FlowLayout(spacing: Spacing.xs) {
                            ForEach(tags, id: \.self) { t in
                                Text(t)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(theme.surfaceSoft)
                                    .foregroundStyle(theme.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    BreathingCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(Copy.SeedDetail.minLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textMuted)
                            Text(seed.minimumAction)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            SeedMetaRow(seed: seed)
                                .padding(.top, Spacing.xs)
                        }
                    }

                    // The pursuit's 手帐 — its notes, ideas, and growth directions.
                    PursuitPageView(seed: seed)

                    actions(seed)
                }
                .padding(Spacing.lg)
            } else {
                Text(Copy.SeedDetail.notFound)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .padding(Spacing.lg)
            }
        }
        .themedScreen()
        .navigationTitle(Copy.SeedDetail.titleLabel)
        .inlineNavTitle()
    }

    @ViewBuilder private func actions(_ seed: Seed) -> some View {
        VStack(spacing: Spacing.sm) {
            switch seed.status {
            case .active:
                SoftButton(title: Copy.SeedDetail.sleep, variant: .soft) {
                    store.setSeedStatus(seed.id, .sleeping)
                }
                SoftButton(title: Copy.SeedDetail.archive, variant: .ghost) {
                    store.setSeedStatus(seed.id, .archived); dismiss()
                }
            case .sleeping:
                SoftButton(title: Copy.SeedDetail.wake) {
                    store.setSeedStatus(seed.id, .active)
                }
                SoftButton(title: Copy.SeedDetail.archive, variant: .ghost) {
                    store.setSeedStatus(seed.id, .archived); dismiss()
                }
            case .archived:
                SoftButton(title: Copy.SeedDetail.restore) {
                    store.setSeedStatus(seed.id, .active)
                }
            case .completed:
                EmptyView()
            }
        }
    }

    private func statusText(_ status: SeedStatus) -> String {
        switch status {
        case .active: return Copy.SeedDetail.statusActive
        case .sleeping: return Copy.SeedDetail.statusSleeping
        case .archived: return Copy.SeedDetail.statusArchived
        case .completed: return ""
        }
    }
}
