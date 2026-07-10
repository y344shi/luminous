//
//  PencilNote.swift
//  Luminous — a handwritten 便签 for the 手帐, drawn with Apple Pencil (or a
//  finger). PencilKit is iPad/Pencil-centric; this whole surface is gated to
//  iOS and degrades to nothing on macOS. A sketch note stores its PKDrawing as
//  base64 in the note's text (no schema change), rendered inline in the deck.
//

import SwiftUI

#if canImport(PencilKit) && os(iOS)
import PencilKit

/// A PencilKit canvas bound to one drawing. Finger + Pencil (drawingPolicy
/// .anyInput), with the system tool picker.
struct SketchCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.drawing = drawing
        canvas.backgroundColor = .clear
        canvas.alwaysBounceVertical = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Surface the tool picker once the canvas is in a window.
        guard canvas.window != nil, !canvas.isFirstResponder else { return }
        let picker = context.coordinator.picker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        canvas.becomeFirstResponder()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: SketchCanvas
        let picker = PKToolPicker()
        init(_ parent: SketchCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

/// A sheet that composes one handwritten note and hands back its base64 on save.
struct SketchComposerSheet: View {
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var drawing = PKDrawing()

    var body: some View {
        NavigationStack {
            SketchCanvas(drawing: $drawing)
                .background(theme.surface)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("画一张")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("记下") {
                            if !drawing.strokes.isEmpty { onSave(SketchNote.encode(drawing)) }
                            dismiss()
                        }
                    }
                }
        }
    }
}
#endif

/// Encode / decode a handwritten note. Kept tiny and platform-safe: the decode
/// helpers return nil off-iOS so a `.sketch` note simply shows a placeholder.
enum SketchNote {

    #if canImport(PencilKit) && os(iOS)
    static func encode(_ drawing: PKDrawing) -> String {
        drawing.dataRepresentation().base64EncodedString()
    }

    static func drawing(fromBase64 s: String) -> PKDrawing? {
        guard let data = Data(base64Encoded: s) else { return nil }
        return try? PKDrawing(data: data)
    }

    /// A SwiftUI image of the stored drawing, or nil if it can't be decoded.
    static func image(fromBase64 s: String) -> Image? {
        guard let drawing = drawing(fromBase64: s) else { return nil }
        let raw = drawing.bounds
        let bounds = (raw.isNull || raw.isEmpty)
            ? CGRect(x: 0, y: 0, width: 1, height: 1)
            : raw.insetBy(dx: -10, dy: -10)
        let ui = drawing.image(from: bounds, scale: UIScreen.main.scale)
        return Image(uiImage: ui)
    }
    #else
    static func image(fromBase64 s: String) -> Image? { nil }
    #endif

    /// True when this device can create handwritten notes.
    static var canDraw: Bool {
        #if canImport(PencilKit) && os(iOS)
        return true
        #else
        return false
        #endif
    }
}
