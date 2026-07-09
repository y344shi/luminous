//
//  FeltRatingView.swift
//  Luminous — 刚才那件事，感觉怎么样?
//
//  One gentle, optional question after a wish is done. The answer grows today's
//  little machine ONE part (see DayToy / BUILD-TODAY-PLAN.md). Never a 1–5 star
//  scale, never a score, never a gate — skipping is a whole answer too and
//  quietly means「很小，但真的」. Warm, quick, theme-token styled.
//

import SwiftUI

struct FeltRatingView: View {
    @Environment(\.theme) private var theme

    /// Called with the chosen feel (or the skip default). The caller records the
    /// part and dismisses; this view just asks.
    let onChoice: (PartFeel) -> Void

    /// The three soft answers, in rising warmth.
    private let feels: [PartFeel] = [.tinyButReal, .feltGood, .changedMyDay]

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("刚才那件事，感觉怎么样?")
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textPrimary)

            Text("今天的小机器，会多一个零件")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)

            VStack(spacing: Spacing.sm) {
                ForEach(feels, id: \.self) { feel in
                    Button { onChoice(feel) } label: {
                        Text(feel.label)
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(theme.accentText)
                            .background(theme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.xs)

            // Skipping is a whole answer — the quietest part, not a penalty.
            Button { onChoice(.tinyButReal) } label: {
                Text("先不说")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
    }
}
