"use client";

import { useState } from "react";
import { useStore } from "@/lib/store";
import { copy } from "@/lib/copy";
import { localDateKey } from "@/lib/utils";
import { wrapByWidth, keepsakeFilename } from "@/lib/keepsake";
import SoftButton from "@/components/design/SoftButton";

/**
 * Renders today's trace into a warm keepsake card (canvas → PNG) the user can
 * save or share. It's a memento, not a metric — one quiet line of "today didn't
 * disappear," in the app's own hand.
 */
export default function KeepsakeButton() {
  const hydrated = useStore((s) => s.hydrated);
  const traces = useStore((s) => s.traces);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  if (!hydrated) return null;
  const today = localDateKey();
  const todays = traces.filter((t) => t.date === today);
  if (todays.length === 0) return null;
  const trace = todays[todays.length - 1];

  function draw(): HTMLCanvasElement {
    const W = 1080;
    const H = 1350;
    const canvas = document.createElement("canvas");
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext("2d")!;

    // warm paper background
    const g = ctx.createLinearGradient(0, 0, W, H);
    g.addColorStop(0, "#f8f1e3");
    g.addColorStop(1, "#efe3cf");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // soft sage glow
    const glow = ctx.createRadialGradient(W / 2, H * 0.4, 60, W / 2, H * 0.4, 620);
    glow.addColorStop(0, "rgba(125,154,122,0.20)");
    glow.addColorStop(1, "rgba(125,154,122,0)");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, W, H);

    ctx.textAlign = "center";

    // wordmark
    ctx.fillStyle = "#827868";
    ctx.font = '300 34px "Songti SC", "Noto Serif SC", serif';
    ctx.fillText("今 天 别 消 失", W / 2, 150);

    // a small sprout mark
    ctx.fillStyle = "#7d9a7a";
    ctx.beginPath();
    ctx.arc(W / 2, 250, 9, 0, Math.PI * 2);
    ctx.fill();

    // the trace text, wrapped
    const lines = wrapByWidth(trace.text, 13);
    ctx.fillStyle = "#3a342c";
    ctx.font = '400 60px "Songti SC", "Noto Serif SC", serif';
    const lineH = 92;
    const startY = H / 2 - ((lines.length - 1) * lineH) / 2;
    lines.forEach((ln, i) => ctx.fillText(ln, W / 2, startY + i * lineH));

    // date + mark
    ctx.fillStyle = "#9a8f7c";
    ctx.font = '300 30px "Songti SC", serif';
    ctx.fillText(trace.date, W / 2, H - 150);
    ctx.font = "300 24px ui-sans-serif, system-ui, sans-serif";
    ctx.fillStyle = "#b3a48e";
    ctx.fillText("luminous", W / 2, H - 100);

    return canvas;
  }

  async function save() {
    setBusy(true);
    try {
      const canvas = draw();
      const blob: Blob | null = await new Promise((res) => canvas.toBlob(res, "image/png"));
      if (!blob) throw new Error("no blob");
      const file = new File([blob], keepsakeFilename(trace.date), { type: "image/png" });

      const navShare = navigator as Navigator & {
        canShare?: (d: { files: File[] }) => boolean;
        share?: (d: { files: File[] }) => Promise<void>;
      };
      if (navShare.canShare?.({ files: [file] }) && navShare.share) {
        await navShare.share({ files: [file] });
      } else {
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = file.name;
        a.click();
        URL.revokeObjectURL(url);
      }
      setDone(true);
      setTimeout(() => setDone(false), 2500);
    } catch {
      /* user cancelled share or no canvas — quietly ignore */
    } finally {
      setBusy(false);
    }
  }

  return (
    <SoftButton variant="soft" onClick={save} disabled={busy}>
      {done ? copy.traces.saveCardDone : copy.traces.saveCard}
    </SoftButton>
  );
}
