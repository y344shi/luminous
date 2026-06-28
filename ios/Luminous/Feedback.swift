//
//  Feedback.swift
//  Luminous — Direction C · Calm Ritual
//
//  Gentle haptics on completion — a small bodily acknowledgement, never a
//  reward/streak. Port of the web Direction C "haptics + soft chime" step.
//  Soft by design: success for complete, a soft tap for partial, the lightest
//  touch for skipped (skipped never "disappears", but it shouldn't celebrate).
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Feedback {
    static func completion(_ kind: CompletionKind) {
        #if os(iOS)
        switch kind {
        case .completed:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .partial:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        case .skipped:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
        #endif
    }
}
