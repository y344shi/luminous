//
//  PaperBackground.swift
//  Luminous — Direction C · Calm Ritual
//
//  A warm "field-notebook" wallpaper behind Home: cream paper, faint ruled
//  lines, a soft left margin rule, and a little grain — tactile and slow.
//  iOS port of the web Direction C "PaperHome" aesthetic.
//

import SwiftUI

struct PaperBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            Canvas { ctx, size in
                // horizontal ruled lines
                let gap: CGFloat = 34
                var y: CGFloat = gap * 1.5
                while y < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(theme.border.opacity(0.55)), lineWidth: 0.6)
                    y += gap
                }

                // left margin rule (gentle accent)
                var margin = Path()
                margin.move(to: CGPoint(x: 40, y: 0))
                margin.addLine(to: CGPoint(x: 40, y: size.height))
                ctx.stroke(margin, with: .color(theme.accentSoft.opacity(0.9)), lineWidth: 1.2)

                // faint paper grain
                for i in 0 ..< 220 {
                    let fi = CGFloat(i)
                    let x = abs((sin(fi * 12.9898) * 43758.547).truncatingRemainder(dividingBy: 1)) * size.width
                    let yy = abs((sin(fi * 78.233) * 12543.13).truncatingRemainder(dividingBy: 1)) * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: yy, width: 0.8, height: 0.8)),
                             with: .color(theme.textMuted.opacity(0.06)))
                }
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PaperBackground().environment(\.theme, Theme.tokens(for: .fieldNotebook))
}
