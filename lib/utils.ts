// Small shared helpers. No side effects beyond id/date generation.

export function uid(prefix = "id"): string {
  const rand = Math.random().toString(36).slice(2, 10);
  const time = Date.now().toString(36);
  return `${prefix}_${time}${rand}`;
}

export function nowIso(): string {
  return new Date().toISOString();
}

/** Local date as YYYY-MM-DD (not UTC) so "today" matches the user's day. */
export function localDateKey(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

/**
 * Human-friendly label for a YYYY-MM-DD trace date, relative to `today`:
 * 今天 / 昨天 / 前天, else "M月D日" (with year only if it differs from today).
 * `today` is injectable so it's deterministic to test.
 */
export function friendlyDate(dateKey: string, today: Date = new Date()): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateKey);
  if (!m) return dateKey;
  const [, y, mo, d] = m;
  const date = new Date(Number(y), Number(mo) - 1, Number(d));
  const base = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const dayMs = 86_400_000;
  const diff = Math.round((base.getTime() - date.getTime()) / dayMs);
  if (diff === 0) return "今天";
  if (diff === 1) return "昨天";
  if (diff === 2) return "前天";
  const md = `${Number(mo)}月${Number(d)}日`;
  return date.getFullYear() === today.getFullYear() ? md : `${y}年${md}`;
}

export function cx(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}
