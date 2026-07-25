//
//  BookScanView.swift
//  Luminous — 扫书: the shelf of scanned books.
//
//  Scan a new book (Apple's document scanner) → name it → its first page becomes
//  the cover, pages saved upright as entries (BookStore). Tap a book to open the
//  split reader (BookReaderView): the page on top, tap-to-explain words below.
//  Rough cut — a useful travel tool; deeper study in WORD-STUDY-PLAN.md.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct BookScanView: View {
    @Environment(\.theme) private var theme

    @State private var books: [Book] = []
    @State private var showScanner = false
    @State private var pending: [Data] = []       // scanned pages awaiting a name
    @State private var showNaming = false
    @State private var draftName = ""
    @State private var openBook: Book?
    @State private var editing = false
    @State private var shareURL: ShareItem?
    @State private var showImporter = false
    @State private var importMessage: String?

    // Transcribe / export / full-book lesson
    @State private var pendingExport: ExportAction?
    @State private var showTranscribeAsk = false
    @State private var working = false
    @State private var workStatus = ""
    @State private var lessonSheet: LessonSheet?

    private struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    private struct LessonSheet: Identifiable { let id = UUID(); let book: Book; let text: String }
    private enum ExportAction {
        case xml(Book), json(Book), lesson(Book)
        var book: Book { switch self { case .xml(let b), .json(let b), .lesson(let b): return b } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("扫一本书，之后一页一页读、一个词一个词认。")
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textSecondary)
                    scanButton
                    importButton
                    if books.isEmpty {
                        Text("书架还空着。扫一本书放上来，或从别的设备隔空投送过来。")
                            .font(.system(size: 13)).foregroundStyle(theme.textMuted).padding(.top, 4)
                    } else {
                        shelf
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("扫书")
            .inlineNavTitle()
            .toolbar {
                if !books.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(editing ? "完成" : "整理") { editing.toggle() }
                            .foregroundStyle(theme.accentText)
                    }
                }
            }
            .navigationDestination(item: $openBook) { book in
                BookReaderView(book: book)
            }
        }
        .onAppear(perform: reload)
        #if canImport(VisionKit) && os(iOS)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner(
                onFinish: { images in
                    showScanner = false
                    let data = images.compactMap { $0.jpegData(compressionQuality: 0.9) }
                    if !data.isEmpty {
                        pending = data
                        draftName = "第 \(books.count + 1) 本书"
                        showNaming = true
                    }
                },
                onCancel: { showScanner = false })
            .ignoresSafeArea()
        }
        #endif
        .alert("给这本书起个名字", isPresented: $showNaming) {
            TextField("书名", text: $draftName)
            Button("存下") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                BookStore.create(name: name.isEmpty ? "第 \(books.count + 1) 本书" : name, pages: pending)
                pending = []; reload()
            }
            Button("取消", role: .cancel) { pending = [] }
        } message: {
            Text("第一页会成为它的封面。")
        }
        #if os(iOS)
        .sheet(item: $shareURL) { item in
            ActivityView(items: [item.url])
        }
        #endif
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if BookArchive.importArchive(from: url) != nil { reload() }
                    else { importMessage = "这个文件读不出来，可能不是一本 Luminous 书。" }
                }
            case .failure:
                importMessage = "没能导入这本书。"
            }
        }
        .alert("导入", isPresented: Binding(get: { importMessage != nil },
                                          set: { if !$0 { importMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(importMessage ?? "") }
        .alert("把这本书转写成文字？", isPresented: $showTranscribeAsk) {
            Button("转写并继续") { BookPrefs.hasAsked = true; runPending() }
            Button("以后一直转写") { BookPrefs.hasAsked = true; BookPrefs.transcribeEnabled = true; runPending() }
            Button("取消", role: .cancel) { BookPrefs.hasAsked = true; pendingExport = nil }
        } message: {
            Text("会识别这本书每一页上的文字（在本机完成）。之后就能导出成学习文档，或让 AI 讲整本书。可以在设置里改。")
        }
        .sheet(item: $lessonSheet) { s in FullBookLessonView(book: s.book, text: s.text) }
        .overlay { if working { workingOverlay } }
    }

    private var workingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView()
                Text(workStatus.isEmpty ? "处理中…" : workStatus)
                    .font(.system(size: 14)).foregroundStyle(.white)
            }
            .padding(Spacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: transcribe → export / lesson

    private func begin(_ action: ExportAction) {
        pendingExport = action
        if BookPrefs.transcribeEnabled { runPending() }
        else { showTranscribeAsk = true }
    }

    private func runPending() {
        guard let action = pendingExport else { return }
        pendingExport = nil
        working = true; workStatus = "正在转写…"
        let bump: @Sendable (Int, Int) -> Void = { p, t in
            Task { @MainActor in workStatus = "正在转写… \(p)/\(t)" }
        }
        Task {
            switch action {
            case .xml(let book):
                let url = await BookExport.export(book, as: .xml, progress: bump)
                await MainActor.run { working = false; if let url { shareURL = ShareItem(url: url) } }
            case .json(let book):
                let url = await BookExport.export(book, as: .json, progress: bump)
                await MainActor.run { working = false; if let url { shareURL = ShareItem(url: url) } }
            case .lesson(let book):
                await MainActor.run { workStatus = "正在备整本书的课…" }
                let text = await BookExport.fullBookLesson(book, progress: bump)
                await MainActor.run {
                    working = false
                    if let text { lessonSheet = LessonSheet(book: book, text: text) }
                    else { importMessage = "这次没能生成——云端连不上，或本机模型不可用。可在设置里切换 AI 模式后再试。" }
                }
            }
        }
    }

    private var importButton: some View {
        Button { showImporter = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down").font(.system(size: 15))
                Text("导入一本书（隔空投送 / 文件）")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(theme.textSecondary)
            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: scan entry

    @ViewBuilder private var scanButton: some View {
        #if canImport(VisionKit) && os(iOS)
        if DocumentScanner.isSupported {
            Button { showScanner = true } label: { scanLabel }
                .buttonStyle(.plain)
        } else { unavailable }
        #else
        unavailable
        #endif
    }

    private var scanLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.viewfinder").font(.system(size: 22, weight: .light))
            VStack(alignment: .leading, spacing: 2) {
                Text("扫一本新书").font(.system(size: 16, weight: .medium))
                Text("翻页就好 — 拍清楚了它自己会拍下来")
                    .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .foregroundStyle(theme.accentText)
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unavailable: some View {
        Text("扫描需要在 iPhone / iPad 上用相机。")
            .font(.system(size: 13)).foregroundStyle(theme.textMuted)
            .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceSoft).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: the shelf

    private var shelf: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.md)],
                  alignment: .leading, spacing: Spacing.md) {
            ForEach(books) { book in bookCell(book) }
        }
    }

    @ViewBuilder private func bookCell(_ book: Book) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if !editing { openBook = book }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    cover(book)
                    Text(book.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textPrimary).lineLimit(1)
                    Text("\(book.pageCount) 页")
                        .font(.system(size: 11)).foregroundStyle(theme.textMuted)
                }
            }
            .buttonStyle(.plain)
            if editing {
                Button { BookStore.delete(book.id); reload() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20)).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain).padding(5)
                .accessibilityLabel("删除这本书")
            }
        }
        .contextMenu {
            Button { if let url = BookArchive.export(book) { shareURL = ShareItem(url: url) } } label: {
                Label("分享 / 隔空投送（.luminousbook）", systemImage: "square.and.arrow.up")
            }
            Menu {
                Button { begin(.xml(book)) } label: { Label("XML（注释文档）", systemImage: "doc.text") }
                Button { begin(.json(book)) } label: { Label("JSON", systemImage: "curlybraces") }
            } label: {
                Label("导出学习文档", systemImage: "square.and.arrow.up.on.square")
            }
            Button { begin(.lesson(book)) } label: {
                Label("生成整本书的课（云端）", systemImage: "graduationcap")
            }
            Button(role: .destructive) { BookStore.delete(book.id); reload() } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder private func cover(_ book: Book) -> some View {
        if let url = book.cover, let data = BookStore.data(for: url), let img = platformImage(data) {
            img.resizable().scaledToFill()
                .frame(height: 150).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 12).fill(theme.surfaceSoft).frame(height: 150)
        }
    }

    private func platformImage(_ data: Data) -> Image? {
        #if canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }

    private func reload() { books = BookStore.books() }
}

/// The full-book lesson (Markdown from the cloud model) — scrollable, selectable,
/// and shareable out as a .md file (e.g. to Notes / ChatGPT / Files).
private struct FullBookLessonView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let text: String
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(rendered)
                    .font(.system(size: 15)).lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .foregroundStyle(theme.textPrimary)
            }
            .themedScreen()
            .navigationTitle("整本书的课")
            .inlineNavTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { shareURL = writeMarkdown() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
                #endif
            }
            #if os(iOS)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
            #endif
        }
    }

    /// Best-effort Markdown → attributed; falls back to plain text.
    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func writeMarkdown() -> URL? {
        let safe = book.name.isEmpty ? "book" : book.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe) · 整本书的课.md")
        do { try text.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}

/// Shown with the first page (and from the shelf): the whole book's vocabulary,
/// ordered by how often each word appears, plus a one-tap "teach the whole book"
/// lesson (cloud model, or the local AI when cloud is off / unreachable).
struct BookOverviewView: View {
    @Environment(\.theme) private var theme
    let book: Book

    @State private var ranked: [(word: String, count: Int)] = []
    @State private var language: String?
    @State private var loading = true
    @State private var generating = false
    @State private var status = ""
    @State private var lesson: LessonBox?
    @State private var selection: WordSelection?
    @State private var noteMessage: String?
    @State private var pasting = false

    private struct LessonBox: Identifiable { let id = UUID(); let text: String }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                vocabSection
                lessonSection
            }
            .padding(Spacing.lg)
        }
        .themedScreen()
        .navigationTitle("词汇与语法")
        .inlineNavTitle()
        .task { await load() }
        .alert("没生成出来", isPresented: Binding(get: { noteMessage != nil }, set: { if !$0 { noteMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(noteMessage ?? "") }
    }

    private var vocabSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("本书词汇 · 按出现频率")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
            if loading {
                HStack(spacing: 10) { ProgressView(); Text("正在转写整本书…")
                    .font(.system(size: 13)).foregroundStyle(theme.textSecondary) }
            } else if ranked.isEmpty {
                Text("这本书还没认出文字。").font(.system(size: 13)).foregroundStyle(theme.textMuted)
            } else {
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(Array(ranked.prefix(150).enumerated()), id: \.offset) { _, item in
                        Button { selection = WordSelection(word: item.word, language: language) } label: {
                            HStack(spacing: 4) {
                                Text(item.word).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)
                                Text("\(item.count)").font(.system(size: 11))
                                    .foregroundStyle(theme.accentText)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.border, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }
                Text("共 \(ranked.count) 个不同的词，越靠前出现得越多。点一个看释义、英文和例句。")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
            }
        }
        .sheet(item: $selection) { s in WordDetailView(word: s.word, language: s.language) }
    }

    private var lessonSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("整本书的课 · 词汇与语法")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text(CloudLLM.isConfigured
                 ? "把整本书的词和语法讲一遍——先用云端，连不上就用本机。"
                 : "把整本书的词和语法讲一遍——用本机 AI（Apple Intelligence）。")
                .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
            if generating {
                HStack(spacing: 10) { ProgressView()
                    Text(status.isEmpty ? "正在备课…" : status)
                        .font(.system(size: 13)).foregroundStyle(theme.textSecondary) }
            } else {
                FlowLayout(spacing: Spacing.sm) {
                    SoftButton(title: "生成整本书的课", variant: .solid, full: false) { generate(force: false) }
                    if let cached = BookExport.cachedLesson(book) {
                        SoftButton(title: "看", variant: .soft, full: false) { lesson = LessonBox(text: cached) }
                        SoftButton(title: "重做", variant: .ghost, full: false) { generate(force: true) }
                    }
                    SoftButton(title: "粘贴 ChatGPT 的课", variant: .ghost, full: false) { pasting = true }
                }
            }
            Text("也可以把书导出成 XML/JSON 发给 ChatGPT，做出更详细的课，再粘回来——它会和这本书一起保存。")
                .font(.system(size: 12)).lineSpacing(2).foregroundStyle(theme.textMuted)
        }
        .sheet(item: $lesson) { l in FullBookLessonView(book: book, text: l.text) }
        .sheet(isPresented: $pasting) {
            LessonPasteEditor(initial: BookExport.cachedLesson(book) ?? "") { saved in
                BookExport.saveLesson(saved, book: book)
                lesson = LessonBox(text: saved)
            }
        }
    }

    private func load() async {
        let docs = await BookExport.transcribe(book)
        await MainActor.run {
            ranked = BookExport.vocabularyRanked(docs)
            language = BookExport.language(of: docs)
            loading = false
            // Don't auto-open a cached lesson; just note it's there (重做 shows).
        }
    }

    private func generate(force: Bool) {
        generating = true; status = "正在转写…"
        let bump: @Sendable (Int, Int) -> Void = { p, t in
            Task { @MainActor in status = "正在转写… \(p)/\(t)" }
        }
        Task {
            await MainActor.run { status = "正在备整本书的课（可能要一两分钟）…" }
            let outcome = await BookExport.fullBookLessonOutcome(book, force: force, progress: bump)
            await MainActor.run {
                generating = false
                switch outcome {
                case .ok(let text): lesson = LessonBox(text: text)
                case .failed(let reason): noteMessage = reason
                }
            }
        }
    }
}

/// Paste a lesson (e.g. from ChatGPT) to keep it with the book.
private struct LessonPasteEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let initial: String
    let onSave: (String) -> Void
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("把 ChatGPT（或别处）做好的课粘到这里，保存后就和这本书一起留着，可在“看”里读，也能分享成 .md。支持 Markdown。")
                    .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
                TextEditor(text: $text)
                    .font(.system(size: 14)).lineSpacing(3)
                    .padding(8)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
            }
            .padding(Spacing.lg)
            .themedScreen()
            .navigationTitle("粘贴课文")
            .inlineNavTitle()
            .onAppear { if text.isEmpty { text = initial } }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
        }
    }
}

#if os(iOS)
/// A share sheet (AirDrop, Files, Messages…) for the exported book file.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
