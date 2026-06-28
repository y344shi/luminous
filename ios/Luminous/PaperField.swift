//
//  PaperField.swift
//  Luminous — skin · Paper
//
//  A warm ruled-notebook backdrop for the paper skin. A calm sheet with
//  faint horizontal rules and a single margin line — no motion, no glass.
//  Colors come from the active theme so it stays in tune with every palette.
//

import SwiftUI

struct PaperField: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.surface.ignoresSafeArea()

            Canvas { ctx, size in
                // Faint horizontal rules.
                let spacing: CGFloat = 32
                var y = spacing
                while y < size.height {
                    var rule = Path()
                    rule.move(to: CGPoint(x: 0, y: y))
                    rule.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(rule, with: .color(theme.border.opacity(0.6)), lineWidth: 1)
                    y += spacing
                }

                // A single warm margin line down the left.
                let marginX = size.width * 0.12
                var margin = Path()
                margin.move(to: CGPoint(x: marginX, y: 0))
                margin.addLine(to: CGPoint(x: marginX, y: size.height))
                ctx.stroke(margin, with: .color(theme.accent.opacity(0.35)), lineWidth: 1.5)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PaperField()
        .environment(\.theme, Theme.tokens(for: .warmPaper))
}
