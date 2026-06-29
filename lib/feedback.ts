/**
 * Tiny, optional sensory feedback for finishing a small thing — a gentle haptic
 * and (only if enabled) a soft chime. Everything is guarded + fail-soft: no-ops
 * where unsupported (desktop, no AudioContext), never throws. Framework-free.
 */

/** A soft double-tap haptic (on devices that support vibration). */
export function hapticComplete(): void {
  try {
    if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
      navigator.vibrate([8, 26, 14]);
    }
  } catch {
    /* ignore */
  }
}

let audioCtx: AudioContext | null = null;

/** A brief, gentle rising sine chime (like a small bell). */
export function chimeComplete(): void {
  try {
    if (typeof window === "undefined") return;
    const AC =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    audioCtx = audioCtx ?? new AC();
    const t = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(660, t);
    osc.frequency.exponentialRampToValueAtTime(880, t + 0.18);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.06, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.5);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + 0.55);
  } catch {
    /* ignore */
  }
}

/** Haptic always (gentle); chime only when the user has turned sound on. */
export function completeFeedback(sound = false): void {
  hapticComplete();
  if (sound) chimeComplete();
}
