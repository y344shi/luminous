//
//  PageAnnotator.swift
//  Luminous — 扫书: draw on a book page with Apple Pencil.
//
//  A full-screen editor: the scanned page fitted to the screen, a PencilKit
//  canvas laid exactly over it (finger or Pencil), the system tool picker, and
//  Done → saves the page's annotation (the editable PKDrawing + a rendered
//  transparent PNG for the reader overlay). Because the canvas matches the
//  page's fitted rect, the PNG shares the page's aspect ratio, so the reader can
//  overlay it with scaledToFit and it lines up. iOS/iPadOS only (Pencil is an
//  iPad affordance); degrades to nothing elsewhere.
//

import SwiftUI

#if canImport(PencilKit) && os(iOS)
import PencilKit
import UIKit

struct PageAnnotator: View {
    let pageURL: URL
    let image: UIImage
    var onClose: () -> Void

    @Environment(\.theme) private var theme
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let rect = fittedRect(imageSize: image.size, in: geo.size)
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    AnnotationCanvas(drawing: $drawing)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .onAppear {
                    if let data = BookStore.annotation(for: pageURL),
                       let d = try? PKDrawing(data: data) { drawing = d }
                }
                .navigationTitle("批注")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { save(canvasSize: rect.size); onClose() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("清空") { drawing = PKDrawing() }
                            .foregroundStyle(theme.accentText)
                    }
                }
            }
        }
    }

    private func save(canvasSize: CGSize) {
        if drawing.strokes.isEmpty {
            BookStore.saveAnnotation(nil, png: nil, for: pageURL)   // cleared
            return
        }
        let data = drawing.dataRepresentation()
        let rect = CGRect(origin: .zero, size: canvasSize == .zero ? CGSize(width: 1, height: 1) : canvasSize)
        let png = drawing.image(from: rect, scale: UIScreen.main.scale).pngData()
        BookStore.saveAnnotation(data, png: png, for: pageURL)
    }

    /// The rect an aspect-fit image occupies inside `container`.
    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: container) }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(origin: .zero, size: size)
    }
}

/// A PencilKit canvas over a clear background, its drawing bound out. Finger +
/// Pencil, with the system tool picker.
private struct AnnotationCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing { canvas.drawing = drawing }
        guard canvas.window != nil, !canvas.isFirstResponder else { return }
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: AnnotationCanvas
        let picker = PKToolPicker()
        init(_ parent: AnnotationCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}
#endif
