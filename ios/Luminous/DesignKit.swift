//
//  DesignKit.swift
//  Luminous
//
//  Reusable presentational pieces — the iOS analogue of components/design/*.
//  One primary action per screen, large whitespace, soft motion.
//

import SwiftUI

// MARK: - SoftButton (port of design/SoftButton.tsx)

struct SoftButton: View {
    enum Variant { case solid, soft, ghost }

    @Environment(\.theme) private var theme

    let title: String
    var variant: Variant = .solid
    var full: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: full ? .infinity : nil)
                .padding(.vertical, 14)
                .padding(.horizontal, full ? 0 : 22)
                .foregroundStyle(foreground)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: variant == .ghost ? 1 : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .opacity(enabled ? 1 : 0.4)
                .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeOut(duration: 0.15), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    private var foreground: Color {
        switch variant {
        case .solid: return theme.onAccent
        case .soft: return theme.textPrimary
        case .ghost: return theme.textSecondary
        }
    }

    private var background: Color {
        switch variant {
        case .solid: return theme.accent
        case .soft: return theme.accentSoft
        case .ghost: return .clear
        }
    }

    private var strokeColor: Color {
        variant == .ghost ? theme.border : .clear
    }
}

// MARK: - BreathingCard (port of design/BreathingCard.tsx)

struct BreathingCard<Content: View>: View {
    @Environment(\.theme) private var theme
    var soft: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(soft ? theme.surfaceSoft : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Chip (port of context/Pickers.tsx)

struct Chip: View {
    @Environment(\.theme) private var theme
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(active ? theme.textPrimary : theme.textSecondary)
                .background(active ? theme.accentSoft : theme.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(active ? theme.accent : theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// A wrapping row of chips. Generic over an Equatable value.
struct ChipGroup<T: Equatable>: View {
    let options: [PickerOption<T>]
    let isActive: (T) -> Bool
    let onSelect: (T) -> Void

    var body: some View {
        FlowLayout(spacing: Spacing.sm) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                Chip(label: opt.label, active: isActive(opt.value)) {
                    onSelect(opt.value)
                }
            }
        }
    }
}

// MARK: - EmptyState (port of design/EmptyState.tsx)

struct EmptyState: View {
    @Environment(\.theme) private var theme
    let icon: String
    let text: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(icon).font(.system(size: 40))
            Text(text)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let actionLabel = actionLabel, let action = action {
                SoftButton(title: actionLabel, full: false, action: action)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - PageHeader (port of design/PageHeader.tsx)

struct PageHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Themed screen background

struct ThemedScreen: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content.background(theme.background.ignoresSafeArea())
    }
}

extension View {
    func themedScreen() -> some View { modifier(ThemedScreen()) }

    /// iOS-only navigation modifiers, no-ops elsewhere so the shared target
    /// (which also lists macOS) still compiles.
    @ViewBuilder func inlineNavTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func hiddenNavBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}

// MARK: - FlowLayout — wraps chips like flex-wrap

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                rows.append([])
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(v)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
