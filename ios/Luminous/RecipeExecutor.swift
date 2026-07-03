//
//  RecipeExecutor.swift
//  Luminous — the deepest assist yet: from "想做顿好饭" to dinner on the table
//
//  For a cooking wish the model proposes ONE dish that fits the moment, lists
//  the ingredients as a tappable shopping checklist, offers the list to the
//  clipboard, and points at the nearest market/store with a real walking route.
//  The wish isn't just suggested anymore — it's provisioned. Still an offer:
//  nothing runs until tapped, everything degrades silently.
//

import SwiftUI
import MapKit
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenIngredient {
    @Guide(description: "食材名，简短")
    var name: String
    @Guide(description: "大概的量，比如 两个 / 300g / 一小把")
    var amount: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenRecipe {
    @Guide(description: "一道菜的名字，家常、此刻做得出来")
    var dish: String
    @Guide(description: "为什么此刻适合这道菜，一句话，温柔")
    var why: String
    @Guide(description: "需要买的食材，4 到 7 样", .count(5))
    var ingredients: [GenIngredient]
    @Guide(description: "回家后的第一小步，比如 先把米淘上")
    var firstStep: String
}
#endif

struct RecipeHelpView: View {
    let seed: Seed

    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme

    @State private var loading = false
    @State private var dish: String?
    @State private var why = ""
    @State private var firstStep = ""
    @State private var ingredients: [(name: String, amount: String)] = []
    @State private var checked: Set<String> = []
    @State private var walk: RouteFinder.Walk?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let dish {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(dish).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    if !why.isEmpty {
                        Text(why).font(.system(size: 13)).lineSpacing(3)
                            .foregroundStyle(theme.textSecondary)
                    }

                    // The shopping checklist — tap what you already have.
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(ingredients, id: \.name) { ing in
                            Button {
                                if checked.contains(ing.name) { checked.remove(ing.name) }
                                else { checked.insert(ing.name) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: checked.contains(ing.name)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(checked.contains(ing.name)
                                                         ? theme.accent : theme.textMuted)
                                    Text(ing.name).font(.system(size: 14))
                                        .foregroundStyle(theme.textPrimary)
                                        .strikethrough(checked.contains(ing.name),
                                                       color: theme.textMuted)
                                    Text(ing.amount).font(.system(size: 12))
                                        .foregroundStyle(theme.textMuted)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: Spacing.sm) {
                        #if os(iOS)
                        Button {
                            UIPasteboard.general.string = shoppingListText()
                        } label: {
                            chip("抄走清单", system: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        #endif
                        if let shop = nearestShop {
                            Button { shop.mapItem.openInMaps() } label: {
                                chip("\(shop.emoji) \(shop.name) · \(walk?.label ?? shop.distanceLabel)",
                                     system: "map")
                            }
                            .buttonStyle(.plain)
                            .task {
                                walk = await RouteFinder.walking(to: shop.mapItem,
                                                                 from: sensed.coordinate)
                            }
                        }
                    }

                    if !firstStep.isEmpty {
                        Text("回家后的第一步：\(firstStep)")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if AIHelper.isAvailable {
                Button { run() } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.small) }
                        else { Image(systemName: "frying.pan") }
                        Text(loading ? "在想一道菜…" : "帮我想一道菜，连买什么都列好")
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
            }
        }
    }

    private var nearestShop: NearbyPlace? {
        sensed.nearby.first { $0.kind == .market || $0.kind == .store }
    }

    private func shoppingListText() -> String {
        let items = ingredients.filter { !checked.contains($0.name) }
        return (dish.map { "\($0)：" } ?? "")
            + items.map { "\($0.name) \($0.amount)" }.joined(separator: "、")
    }

    private func run() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return }
        loading = true
        let hour = Calendar.current.component(.hour, from: Date())
        var bits = [DayGrade.line(hour: hour)]
        if let w = sensed.weatherKind { bits.append("天气 \(w.rawValue)") }
        let line = bits.joined(separator: "；")
        Task { @MainActor in
            defer { loading = false }
            let instructions = """
            你帮一个想在家做饭的人想一道菜。家常、应季、一小时内能做完；\
            食材在普通超市买得到。语气温柔，不炫技。
            """
            let prompt = "愿望：「\(seed.title)」。此刻：\(line)。请想一道合适的菜。"
            guard let r = try? await LanguageModelSession(instructions: instructions)
                .respond(to: prompt, generating: GenRecipe.self) else { return }
            let g = r.content
            let all = g.dish + g.why + g.firstStep
                + g.ingredients.map { $0.name + $0.amount }.joined()
            guard ForbiddenWords.passes(all), !g.dish.isEmpty,
                  !g.ingredients.isEmpty else { return }
            dish = g.dish
            why = g.why
            firstStep = g.firstStep
            ingredients = g.ingredients.map { ($0.name, $0.amount) }
            checked = []
            store.logEvent(kind: "plan.recipe", payload: g.dish)
        }
        #endif
    }

    private func chip(_ text: String, system: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 11))
            Text(text).font(.system(size: 12, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(theme.accentText)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(theme.accentSoft)
        .clipShape(Capsule())
    }
}
