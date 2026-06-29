import { useCallback, useEffect, useRef, useState } from "react";
import { classifyActivity, classifyAmbient, type Activity, type Ambient } from "@core/sensors";

/**
 * Live, on-device sensing for the recommender. Motion (accelerometer) is sampled
 * passively where the platform allows it; ambient loudness needs an explicit
 * opt-in (microphone). NOTHING is recorded or sent — we read levels, derive a
 * coarse signal, and forget the raw data. Absent/denied senses simply stay
 * undefined and the ranking carries on.
 */
export function useSensors() {
  const [activity, setActivity] = useState<Activity | undefined>(undefined);
  const [ambient, setAmbient] = useState<Ambient | undefined>(undefined);
  const [ambientOn, setAmbientOn] = useState(false);
  const [ambientBlocked, setAmbientBlocked] = useState(false); // mic unavailable/denied → tell the user
  const samplesRef = useRef<number[]>([]);
  const audioRef = useRef<{ ctx: AudioContext; stream: MediaStream; id: number } | null>(null);

  // Passive motion sampling → coarse activity.
  useEffect(() => {
    if (typeof window === "undefined" || !("DeviceMotionEvent" in window)) return;
    const onMotion = (e: DeviceMotionEvent) => {
      const a = e.accelerationIncludingGravity;
      if (!a) return;
      const mag = Math.hypot(a.x ?? 0, a.y ?? 0, a.z ?? 0);
      const arr = samplesRef.current;
      arr.push(mag);
      if (arr.length > 40) arr.shift();
    };
    window.addEventListener("devicemotion", onMotion);
    const id = window.setInterval(() => {
      const act = classifyActivity(samplesRef.current);
      if (act) setActivity(act);
    }, 2500);
    return () => {
      window.removeEventListener("devicemotion", onMotion);
      window.clearInterval(id);
    };
  }, []);

  // Opt-in ambient loudness via the mic (also requests iOS motion permission).
  const enableAmbient = useCallback(async () => {
    if (audioRef.current || typeof navigator === "undefined" || typeof window === "undefined") return;
    // The mic needs a secure context (https or localhost) + the API present. Over a
    // plain-http LAN IP (e.g. testing from a phone) the browser blocks it silently —
    // surface that instead of looking like a dead button.
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
      setAmbientBlocked(true);
      return;
    }
    try {
      // iOS: unlock motion events too, so activity sensing works on the phone.
      const DM = (window as unknown as { DeviceMotionEvent?: { requestPermission?: () => Promise<string> } })
        .DeviceMotionEvent;
      if (DM && typeof DM.requestPermission === "function") {
        await DM.requestPermission().catch(() => {});
      }
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const AC =
        window.AudioContext ??
        (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AC) {
        setAmbientBlocked(true);
        return;
      }
      const ctx = new AC();
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      ctx.createMediaStreamSource(stream).connect(analyser);
      const buf = new Uint8Array(analyser.fftSize);
      const id = window.setInterval(() => {
        analyser.getByteTimeDomainData(buf);
        let sum = 0;
        for (let i = 0; i < buf.length; i++) {
          const v = (buf[i] - 128) / 128;
          sum += v * v;
        }
        setAmbient(classifyAmbient(Math.sqrt(sum / buf.length)));
      }, 1500);
      audioRef.current = { ctx, stream, id };
      setAmbientOn(true);
      setAmbientBlocked(false);
    } catch {
      setAmbientBlocked(true); // denied / unsupported — show a gentle note
    }
  }, []);

  // Stop the mic + audio graph on unmount.
  useEffect(() => {
    return () => {
      const a = audioRef.current;
      if (a) {
        window.clearInterval(a.id);
        a.stream.getTracks().forEach((t) => t.stop());
        a.ctx.close().catch(() => {});
      }
    };
  }, []);

  return { activity, ambient, ambientOn, ambientBlocked, enableAmbient };
}
