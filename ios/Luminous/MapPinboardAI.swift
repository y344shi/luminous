//
//  MapPinboardAI.swift
//  Luminous
//
//  Turns a messy shared link / note into a conservative map search draft.
//  The model never adds a pin directly: MapKit search or manual confirmation
//  owns the final coordinate.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct MapPlaceDraft: Equatable {
    var name: String
    var searchQuery: String
    var address: String
    var note: String

    var bestQuery: String {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty { return address }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty { return query }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fallback(from raw: String) -> MapPlaceDraft {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let first = lines.first ?? trimmed
        let withoutURL = first
            .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = withoutURL.isEmpty ? "新的地点" : String(withoutURL.prefix(42))
        return MapPlaceDraft(name: name, searchQuery: name, address: "", note: "")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GenMapPlaceDraft {
    @Guide(description: "地点名称，最多 40 个字；如果只有链接，就从标题或文字里推断，不要编造不存在的店名")
    var name: String
    @Guide(description: "适合交给地图搜索的一句话，包含城市/地区/店名；不要包含追踪参数")
    var searchQuery: String
    @Guide(description: "明确地址；没有就留空")
    var address: String
    @Guide(description: "一句很短的备注：为什么可能值得去；没有把握就留空")
    var note: String
}
#endif

enum MapPinboardAI {
    static func draft(from raw: String) async -> MapPlaceDraft {
        let fallback = MapPlaceDraft.fallback(from: raw)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), AIHelper.isAvailable {
            if let ai = await llmDraft(raw, fallback: fallback) { return ai }
        }
        #endif
        return fallback
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func llmDraft(_ raw: String, fallback: MapPlaceDraft) async -> MapPlaceDraft? {
        let instructions = """
        你帮用户把一段分享链接、笔记或聊天摘录整理成地图搜索草稿。\
        只提取地点相关信息；不要猜营业时间；不要把链接追踪参数放进搜索词。\
        如果不确定，宁愿给一个保守的搜索词，让地图搜索来确认。
        """
        guard let r = try? await LanguageModelSession(instructions: instructions)
            .respond(to: raw, generating: GenMapPlaceDraft.self) else { return nil }
        let g = r.content
        let name = clean(g.name, max: 40)
        let query = clean(g.searchQuery, max: 80)
        let address = clean(g.address, max: 96)
        let note = clean(g.note, max: 90)
        guard !name.isEmpty || !query.isEmpty || !address.isEmpty else { return nil }
        guard ForbiddenWords.passes(name + query + address + note) else { return nil }
        return MapPlaceDraft(
            name: name.isEmpty ? fallback.name : name,
            searchQuery: query.isEmpty ? fallback.searchQuery : query,
            address: address,
            note: note
        )
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func clean(_ s: String, max: Int) -> String {
        let trimmed = s
            .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(max))
    }
    #endif
}
