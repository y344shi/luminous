//
//  OpportunityCard.swift
//  Luminous
//
//  The single recommended opportunity. Port of opportunity/OpportunityCard.tsx.
//

import SwiftUI

struct OpportunityCard: View {
    @Environment(\.theme) private var theme
    let opportunity: Opportunity
    let seed: Seed
    let canSwap: Bool
    let onStart: () -> Void
    let onSwap: () -> Void
    let onLater: () -> Void

    var body: some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(seed.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                SeedMetaRow(seed: seed)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(Copy.Now.reasonLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                    Text(opportunity.reason)
                        .font(.system(size: 15)).lineSpacing(4)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(Copy.Now.minLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                    Text(opportunity.suggestedAction)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                SoftButton(title: Copy.Now.start) { onStart() }
                HStack(spacing: Spacing.sm) {
                    if canSwap {
                        SoftButton(title: Copy.Now.swap, variant: .soft) { onSwap() }
                    }
                    SoftButton(title: Copy.Now.later, variant: .ghost) { onLater() }
                }
            }
        }
    }
}
