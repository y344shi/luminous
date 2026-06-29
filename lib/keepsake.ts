/**
 * Pure helpers for the trace keepsake card. The canvas drawing lives in the
 * component (needs the DOM); the text layout + filename are pure so they can be
 * tested. CJK-friendly: wraps by character count, honoring existing line breaks.
 */

/** Wrap text into lines of at most `max` chars, preserving explicit newlines. */
export function wrapByWidth(text: string, max = 13): string[] {
  const out: string[] = [];
  for (const para of text.split("\n")) {
    if (para.length === 0) {
      out.push("");
      continue;
    }
    let line = "";
    for (const ch of para) {
      line += ch;
      if (line.length >= max) {
        out.push(line);
        line = "";
      }
    }
    if (line.length) out.push(line);
  }
  return out;
}

/** A stable, friendly filename for the exported card. */
export function keepsakeFilename(date?: string): string {
  const d = date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : "trace";
  return `今天别消失-${d}.png`;
}
