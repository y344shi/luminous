//
//  TranslateView.swift
//  Luminous — "拍一张，两种语言都读给你听"
//
//  Take (or pick) a photo → Vision reads the text → the on-device model translates
//  it into both English and Simplified Chinese. All local; nothing is uploaded.
//

import SwiftUI
import PhotosUI
import ImageIO
#if os(iOS)
import UIKit
#endif

struct TranslateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var cgImage: CGImage?
    @State private var displayOrientation: Image.Orientation = .up
    @State private var ocrText = ""
    @State private var result: Translation?
    @State private var phase: Phase = .idle
    @State private var errorText: String?

    @State private var pickerItem: PhotosPickerItem?
    #if os(iOS)
    @State private var showCamera = false
    #endif

    enum Phase { case idle, reading, translating, done }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    PageHeader(title: "拍照翻译")
                    Text("拍一张有文字的照片 — 招牌、菜单、书页。它会认出是什么语言，再翻成英文和中文。")
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textSecondary)

                    preview
                    inputButtons

                    if let errorText {
                        note(errorText, tint: theme.textMuted)
                    }
                    if phase == .reading || phase == .translating {
                        working
                    }
                    if !ocrText.isEmpty {
                        section(title: "原文", body: ocrText, mono: true)
                    }
                    if let result {
                        section(title: "English" + (result.sourceLanguage.isEmpty ? "" : " · from \(result.sourceLanguage)"),
                                body: result.english)
                        section(title: "简体中文", body: result.chinese)
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("拍照翻译")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadFromPicker(item) }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in
                    showCamera = false
                    Task { await run(on: data) }
                }
                .ignoresSafeArea()
            }
            #endif
        }
    }

    // MARK: pieces

    @ViewBuilder private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.surfaceSoft)
            if let cgImage {
                Image(decorative: cgImage, scale: 1, orientation: displayOrientation)
                    .resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(theme.textMuted)
                    Text("还没有照片").font(.system(size: 13)).foregroundStyle(theme.textMuted)
                }
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
    }

    private var inputButtons: some View {
        HStack(spacing: Spacing.md) {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { beginNew(); showCamera = true } label: {
                    inputLabel("拍照", system: "camera.fill")
                }.buttonStyle(.plain)
            }
            #endif
            PhotosPicker(selection: $pickerItem, matching: .images) {
                inputLabel("从相册选择", system: "photo.on.rectangle")
            }
        }
    }

    private func inputLabel(_ title: String, system: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: system)
            Text(title).font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private var working: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(phase == .reading ? "正在读取文字…" : "正在翻译…")
                .font(.system(size: 14)).foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func section(title: String, body: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textMuted)
            Text(body)
                .font(mono ? .system(size: 14, design: .monospaced) : .system(size: 16))
                .lineSpacing(4)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(Spacing.md)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func note(_ text: String, tint: Color) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: pipeline

    private func beginNew() {
        errorText = nil; ocrText = ""; result = nil; phase = .idle
    }

    private func loadFromPicker(_ item: PhotosPickerItem) async {
        beginNew()
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run { errorText = "读不到这张照片" }; return
            }
            await run(on: data)
        } catch {
            await MainActor.run { errorText = "读不到这张照片" }
        }
    }

    /// The whole flow: decode → OCR → translate.
    private func run(on data: Data) async {
        beginNew()
        guard let (img, orientation) = ImageInput.load(data) else {
            await MainActor.run { errorText = "这张图片没法打开" }; return
        }
        await MainActor.run {
            cgImage = img
            displayOrientation = Self.swiftUIOrientation(orientation)
            phase = .reading
        }
        do {
            let text = try await VisionOCR.recognize(img, orientation: orientation)
            await MainActor.run { ocrText = text }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                await MainActor.run { phase = .idle; errorText = "没找到文字，换个更清楚的角度试试。" }
                return
            }
            guard Translator.isAvailable else {
                await MainActor.run { phase = .idle; errorText = Translator.unavailableReason }
                return
            }
            await MainActor.run { phase = .translating }
            let t = try await Translator.translate(clean)
            await MainActor.run { result = t; phase = .done }
        } catch {
            await MainActor.run { phase = .idle; errorText = "翻译遇到点问题，再试一次。" }
        }
    }

    private static func swiftUIOrientation(_ o: CGImagePropertyOrientation) -> Image.Orientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

// MARK: - Camera (iOS only)

#if os(iOS)
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (Data) -> Void
        init(onCapture: @escaping (Data) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.9) {
                onCapture(data)
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
