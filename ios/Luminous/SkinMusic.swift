//
//  SkinMusic.swift
//  Luminous — a quiet theme song per skin on the dashboard
//
//  Each skin has a track; turning music on loops it softly while you're in the app.
//  Uses the ambient audio session so it respects the silent switch and mixes with
//  anything else playing. The audio files are NOT bundled here — drop them into
//  ios/Luminous/ with these names and they'll play (see the names in `track(for:)`):
//    glass/planetarium → "planetarium"   ocean → "ocean"   paper → "paper"
//  (e.g. planetarium.m4a — "A Memory" by Zachary David, if you have the file).
//

import Foundation
import AVFoundation

@MainActor
@Observable
final class SkinMusic {
    private var player: AVAudioPlayer?
    private var current: Aesthetic?

    /// Reconcile playback with the chosen skin + on/off.
    func update(aesthetic: Aesthetic, on: Bool) {
        guard on else { stop(); return }
        if current == aesthetic, player?.isPlaying == true { return }
        play(aesthetic)
    }

    private func play(_ a: Aesthetic) {
        current = a
        guard let url = Self.url(for: Self.track(for: a)) else { stop(); return }
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            #endif
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1          // loop forever
            p.volume = 0.55
            p.prepareToPlay()
            p.play()
            player?.stop()
            player = p
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
    }

    private static func track(for a: Aesthetic) -> String {
        switch a {
        case .glass: return "planetarium"   // "A Memory" — Zachary David
        case .ocean: return "ocean"
        case .paper: return "paper"
        }
    }

    private static func url(for name: String) -> URL? {
        for ext in ["m4a", "mp3", "aac", "wav"] {
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
        }
        return nil
    }
}
