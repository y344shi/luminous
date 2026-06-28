import type { ReactNode } from "react";

/**
 * Eight illustration "looks", one per library, hand-painted as small swatches in
 * each library's signature style so the choice is visible. The chosen key is
 * stored in settings.illustrationStyle; the actual library assets get wired to
 * the wishes later. See docs/scene-library.md for the sources + licenses.
 */
export type IllustrationStyle = { key: string; name: string; note: string; art: ReactNode };

export const illustrationStyles: IllustrationStyle[] = [
  {
    key: "opendoodles",
    name: "Open Doodles",
    note: "手绘随性 · CC0",
    art: (
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="34" cy="16" r="6" />
        <path d="M34 22 q-2 10 2 16" />
        <path d="M33 27 q-9 0 -12 8" />
        <path d="M35 28 q10 2 16 -2" />
        <path d="M34 38 q-4 6 -3 12 M37 38 q5 6 4 12" />
        <path d="M14 52 q22 -4 46 0" opacity="0.45" />
      </g>
    ),
  },
  {
    key: "storyset",
    name: "Storyset",
    note: "扁平可换色 · 免费",
    art: (
      <g>
        <rect x="12" y="15" width="18" height="33" rx="5" fill="#7d9a7a" />
        <circle cx="21" cy="11" r="6" fill="#e8c8a8" />
        <rect x="50" y="30" width="14" height="18" rx="2" fill="#c9c4ba" />
        <path d="M57 30 V17" stroke="#7d9a7a" strokeWidth="2.4" fill="none" strokeLinecap="round" />
        <path d="M57 23 q-7 -2 -8 -8 M57 21 q7 -2 8 -7" stroke="#7d9a7a" strokeWidth="2.4" fill="none" strokeLinecap="round" />
      </g>
    ),
  },
  {
    key: "pixeltrue",
    name: "Pixeltrue",
    note: "柔和粉彩 · 治愈",
    art: (
      <g>
        <ellipse cx="38" cy="50" rx="22" ry="3" fill="#e9e1d4" />
        <rect x="22" y="26" width="30" height="20" rx="9" fill="#f0d3bd" />
        <path d="M52 30 q9 1 9 7 t-9 7" fill="none" stroke="#e3b79b" strokeWidth="3.2" />
        <path d="M30 22 q-3 -5 0 -10 M40 22 q3 -5 0 -10" stroke="#cfe0c8" strokeWidth="3.2" fill="none" strokeLinecap="round" />
      </g>
    ),
  },
  {
    key: "blush",
    name: "Blush",
    note: "画家手绘 · 暖调",
    art: (
      <g>
        <path d="M12 30 q-2 -17 17 -17 q19 0 17 17 q2 15 -17 17 q-19 -2 -17 -17 Z" fill="#ecc7b0" />
        <path d="M40 39 q15 -11 25 2 q-4 13 -17 11 q-13 -2 -8 -13 Z" fill="#cdd9c2" />
        <circle cx="29" cy="24" r="5" fill="#d98f6a" />
        <path d="M29 29 q-4 8 0 14" stroke="#3a342c" strokeWidth="1.6" fill="none" strokeLinecap="round" />
      </g>
    ),
  },
  {
    key: "humaaans",
    name: "Humaaans",
    note: "可拼人物 · CC BY",
    art: (
      <g>
        <circle cx="40" cy="13" r="6.5" fill="#e3b187" />
        <rect x="33" y="20" width="14" height="20" rx="6" fill="#7d9a7a" />
        <rect x="34" y="38" width="5" height="14" rx="2.5" fill="#5e5448" />
        <rect x="41" y="38" width="5" height="14" rx="2.5" fill="#5e5448" />
        <rect x="28" y="22" width="5" height="14" rx="2.5" fill="#6f8a6c" transform="rotate(10 30 29)" />
      </g>
    ),
  },
  {
    key: "openpeeps",
    name: "Open Peeps",
    note: "手绘人物 · CC0",
    art: (
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M28 24 q0 -13 12 -13 q12 0 12 13 q0 6 -4 9 M30 33 q10 6 20 0 M28 24 q0 6 4 9" />
        <path d="M21 50 q19 -11 38 0" />
        <path d="M36 26 q2 2 4 0" />
      </g>
    ),
  },
  {
    key: "undraw",
    name: "unDraw",
    note: "单色扁平 · 开源",
    art: (
      <g>
        <rect x="13" y="41" width="54" height="4" rx="1" fill="#b9b3a6" />
        <rect x="40" y="21" width="23" height="16" rx="1.5" fill="#7d9a7a" />
        <rect x="49" y="37" width="5" height="4" fill="#b9b3a6" />
        <circle cx="24" cy="29" r="7" fill="#7d9a7a" />
        <path d="M16 41 q8 -10 16 0 Z" fill="#c9c4ba" />
      </g>
    ),
  },
  {
    key: "drawkit",
    name: "DrawKit",
    note: "柔光双色 · 部分免费",
    art: (
      <g>
        <ellipse cx="40" cy="32" rx="27" ry="20" fill="#dfe7d6" />
        <circle cx="40" cy="21" r="6" fill="#9bb592" />
        <g stroke="#5e7458" strokeWidth="2.2" fill="none" strokeLinecap="round">
          <path d="M40 27 q-2 8 0 12" />
          <path d="M40 33 q-11 2 -14 9 M40 33 q11 2 14 9" />
          <path d="M28 47 q12 5 24 0" />
        </g>
      </g>
    ),
  },
];

export function StylePreview({ art }: { art: ReactNode }) {
  return (
    <svg viewBox="0 0 80 56" className="h-full w-full" aria-hidden>
      {art}
    </svg>
  );
}

/** Render the illustration for the active library pack (by settings.illustrationStyle).
 * One interface for all 8 looks — real library assets can replace the art later. */
export function IllustrationArt({ style, className }: { style: string; className?: string }) {
  const pack = illustrationStyles.find((s) => s.key === style) ?? illustrationStyles[0];
  return (
    <svg viewBox="0 0 80 56" className={className ?? "h-full w-full"} aria-hidden>
      {pack.art}
    </svg>
  );
}
