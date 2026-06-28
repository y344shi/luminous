import type { ReactNode } from "react";
import type { SeedCategory } from "@/lib/types";

/**
 * Eight illustration "looks", one per library, hand-painted as small swatches in
 * each library's signature style so the choice is visible. The chosen key is
 * stored in settings.illustrationStyle; the actual library assets get wired to
 * the wishes later. See docs/scene-library.md for the sources + licenses.
 *
 * `art` is the pack's signature scene (used for the swatch). `scene(category)` is
 * the optional per-category illustration — packs grow into it one at a time; until
 * a pack provides it, IllustrationArt falls back to the signature `art`.
 */
export type IllustrationStyle = {
  key: string;
  name: string;
  note: string;
  art: ReactNode;
  scene?: (category: SeedCategory) => ReactNode;
};

// Open Doodles — loose hand-drawn line, one scene per wish category (viewBox 80×56).
const L = { fill: "none", stroke: "#3a342c", strokeWidth: 1.7, strokeLinecap: "round", strokeLinejoin: "round" } as const;
const opendoodlesScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g {...L}>
      <path d="M24 30 Q40 44 56 30" />
      <path d="M24 30 H56" />
      <path d="M34 26 q-3 -4 0 -8" />
      <path d="M46 26 q3 -4 0 -8" />
    </g>
  ),
  creation: (
    <g {...L}>
      <path d="M22 42 Q38 38 54 42" opacity="0.45" />
      <path d="M28 38 L48 18" />
      <path d="M46 16 L52 22 L49 25 L43 19 Z" />
    </g>
  ),
  connection: (
    <g {...L}>
      <ellipse cx="30" cy="33" rx="7" ry="11" transform="rotate(-12 30 33)" />
      <ellipse cx="50" cy="33" rx="7" ry="11" transform="rotate(12 50 33)" />
      <path d="M37 20 q3 -4 6 0" />
    </g>
  ),
  exploration: (
    <g {...L}>
      <path d="M14 40 Q40 34 66 40" />
      <path d="M44 40 Q52 22 60 40" />
      <path d="M20 42 C32 38 28 32 40 30" strokeDasharray="1 4" />
    </g>
  ),
  recovery: (
    <g {...L}>
      <path d="M30 24 C30 16 42 13 50 19 C50 27 38 30 30 24 Z" />
      <path d="M30 24 L48 18" />
      <path d="M16 36 q6 -3 12 0 t12 0 t12 0" />
      <path d="M16 42 q6 -3 12 0 t12 0 t12 0" opacity="0.6" />
    </g>
  ),
  learning: (
    <g {...L}>
      <path d="M40 42 V24" />
      <path d="M20 44 Q40 37 60 44 M20 44 V30 Q30 26 40 30 M60 44 V30 Q50 26 40 30" />
    </g>
  ),
  aesthetic: (
    <g {...L}>
      <path d="M40 24 m-7 0 a7 7 0 1 0 14 0 a7 7 0 1 0 -14 0" />
      <path d="M40 31 V40" />
      <path d="M32 46 L34 40 H46 L48 46 Z" />
    </g>
  ),
};

// Storyset — flat geometric, accent + neutral fills (viewBox 80×56).
const storysetScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <path d="M22 28 Q40 44 58 28 Z" fill="#7d9a7a" />
      <rect x="22" y="26" width="36" height="3" rx="1.5" fill="#5e7458" />
      <rect x="33" y="14" width="3" height="9" rx="1.5" fill="#c4d6bb" />
      <rect x="44" y="14" width="3" height="9" rx="1.5" fill="#c4d6bb" />
    </g>
  ),
  creation: (
    <g>
      <rect x="20" y="18" width="22" height="30" rx="2" fill="#e9e1d4" />
      <rect x="24" y="26" width="14" height="2" fill="#c9c4ba" />
      <rect x="24" y="31" width="14" height="2" fill="#c9c4ba" />
      <g transform="rotate(38 50 32)">
        <rect x="44" y="14" width="6" height="26" rx="2" fill="#7d9a7a" />
        <path d="M44 40 L50 40 L47 46 Z" fill="#5e7458" />
      </g>
    </g>
  ),
  connection: (
    <g>
      <circle cx="26" cy="22" r="6" fill="#e8c8a8" />
      <path d="M18 44 q0 -10 8 -10 q8 0 8 10 Z" fill="#7d9a7a" />
      <circle cx="52" cy="22" r="6" fill="#e8c8a8" />
      <path d="M44 44 q0 -10 8 -10 q8 0 8 10 Z" fill="#c4d6bb" />
      <path d="M39 13 a3 3 0 0 1 6 0 c0 3 -3 4 -3 6 c0 -2 -3 -3 -3 -6 Z" fill="#d98f6a" />
    </g>
  ),
  exploration: (
    <g>
      <circle cx="56" cy="18" r="6" fill="#e8c8a8" />
      <path d="M14 42 Q34 22 54 42 Z" fill="#7d9a7a" />
      <rect x="33" y="20" width="2" height="14" fill="#5e7458" />
      <path d="M35 20 L43 23 L35 26 Z" fill="#d98f6a" />
    </g>
  ),
  recovery: (
    <g>
      <rect x="12" y="38" width="56" height="10" rx="3" fill="#c4d6bb" />
      <path d="M28 22 C28 14 42 12 50 18 C50 26 36 28 28 22 Z" fill="#7d9a7a" />
      <path d="M30 21 L47 17" stroke="#cfe0c8" strokeWidth="1.5" />
    </g>
  ),
  learning: (
    <g>
      <path d="M40 42 L20 38 V20 L40 24 Z" fill="#7d9a7a" />
      <path d="M40 42 L60 38 V20 L40 24 Z" fill="#c4d6bb" />
      <rect x="38" y="24" width="4" height="18" fill="#5e7458" />
    </g>
  ),
  aesthetic: (
    <g>
      <path d="M30 34 H50 L48 47 H32 Z" fill="#c9c4ba" />
      <rect x="39" y="18" width="2" height="16" fill="#5e7458" />
      <path d="M40 27 q-9 -2 -10 -10 q8 0 10 7 Z" fill="#7d9a7a" />
      <path d="M40 25 q9 -3 11 -10 q-8 0 -11 8 Z" fill="#c4d6bb" />
    </g>
  ),
};

// Pixeltrue — soft pastel, rounded, gentle (viewBox 80×56).
const pixeltrueScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <ellipse cx="40" cy="48" rx="20" ry="3" fill="#e9e1d4" />
      <path d="M24 28 q0 16 16 16 q16 0 16 -16 Z" fill="#f0d3bd" />
      <rect x="23" y="26" width="34" height="4" rx="2" fill="#e3b79b" />
      <path d="M33 22 q-3 -5 0 -9 M44 22 q3 -5 0 -9" stroke="#cfe0c8" strokeWidth="3.2" fill="none" strokeLinecap="round" />
    </g>
  ),
  creation: (
    <g>
      <rect x="20" y="18" width="22" height="30" rx="5" fill="#eef0e6" />
      <rect x="25" y="27" width="12" height="3" rx="1.5" fill="#cfe0c8" />
      <rect x="25" y="33" width="12" height="3" rx="1.5" fill="#cfe0c8" />
      <g transform="rotate(38 50 32)">
        <rect x="45" y="16" width="7" height="24" rx="3.5" fill="#e3b79b" />
        <path d="M45 40 q3.5 6 7 0 Z" fill="#d9a07a" />
      </g>
    </g>
  ),
  connection: (
    <g>
      <rect x="16" y="24" width="16" height="22" rx="8" fill="#f0d3bd" />
      <rect x="48" y="24" width="16" height="22" rx="8" fill="#cfe0c8" />
      <circle cx="36" cy="16" r="4" fill="#e8a3a3" />
      <circle cx="44" cy="16" r="4" fill="#e8a3a3" />
      <path d="M32 18 L40 28 L48 18 Z" fill="#e8a3a3" />
    </g>
  ),
  exploration: (
    <g>
      <circle cx="54" cy="18" r="7" fill="#f5d9a8" />
      <path d="M14 44 q14 -22 28 0 Z" fill="#cfe0c8" />
      <path d="M40 44 q12 -16 24 0 Z" fill="#b9cdb0" />
    </g>
  ),
  recovery: (
    <g>
      <rect x="12" y="36" width="56" height="12" rx="6" fill="#cfe0e6" />
      <path d="M28 24 C28 15 44 13 50 20 C50 28 34 30 28 24 Z" fill="#b9cdb0" />
    </g>
  ),
  learning: (
    <g>
      <path d="M40 42 q-10 -6 -20 -4 V22 q10 -2 20 4 Z" fill="#f0d3bd" />
      <path d="M40 42 q10 -6 20 -4 V22 q-10 -2 -20 4 Z" fill="#e3b79b" />
      <rect x="38" y="24" width="4" height="18" rx="2" fill="#cfa98a" />
    </g>
  ),
  aesthetic: (
    <g>
      <g fill="#f0b8c0">
        <circle cx="40" cy="16" r="5" />
        <circle cx="32" cy="22" r="5" />
        <circle cx="48" cy="22" r="5" />
        <circle cx="35" cy="31" r="5" />
        <circle cx="45" cy="31" r="5" />
      </g>
      <circle cx="40" cy="24" r="4.5" fill="#f5d9a8" />
      <path d="M40 31 V46" stroke="#b9cdb0" strokeWidth="3" strokeLinecap="round" />
    </g>
  ),
};


// Blush — warm painterly, soft organic fills (viewBox 80×56).
const blushScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <path d="M37 13 C34 17 40 19 37 23" fill="none" stroke="#e0cdbf" strokeWidth="2.2" strokeLinecap="round" />
      <path d="M44 14 C41 18 47 20 44 24" fill="none" stroke="#e0cdbf" strokeWidth="2.2" strokeLinecap="round" />
      <path d="M25 34 Q26 45 40 46 Q54 45 55 34 Z" fill="#d98f6a" />
      <ellipse cx="40" cy="34" rx="16" ry="4" fill="#f2ead9" />
      <ellipse cx="40" cy="34" rx="12.5" ry="2.6" fill="#ecc7b0" />
    </g>
  ),
  creation: (
    <g>
      <rect x="20" y="20" width="34" height="22" rx="3" fill="#f2ead9" />
      <line x1="26" y1="28" x2="48" y2="28" stroke="#e0cdbf" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="26" y1="33" x2="48" y2="33" stroke="#e0cdbf" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="26" y1="38" x2="42" y2="38" stroke="#e0cdbf" strokeWidth="1.6" strokeLinecap="round" />
      <g transform="rotate(33 40 28)">
        <rect x="37.5" y="16" width="5" height="20" rx="2" fill="#d98f6a" />
        <rect x="37.5" y="14" width="5" height="3.5" rx="1.5" fill="#e6a6a0" />
        <path d="M37.5 36 L42.5 36 L40 41 Z" fill="#f0c891" />
      </g>
    </g>
  ),
  connection: (
    <g>
      <ellipse cx="29" cy="36" rx="9" ry="12" fill="#ecc7b0" transform="rotate(-14 29 36)" />
      <ellipse cx="51" cy="36" rx="9" ry="12" fill="#e6a6a0" transform="rotate(14 51 36)" />
      <path d="M40 27 C40 27 33 22 33 18.5 C33 16.5 35 15.5 36.5 16 C38 16.5 39.2 18 40 19.5 C40.8 18 42 16.5 43.5 16 C45 15.5 47 16.5 47 18.5 C47 22 40 27 40 27 Z" fill="#d98f6a" />
    </g>
  ),
  exploration: (
    <g>
      <circle cx="49" cy="19" r="6.5" fill="#f0c891" />
      <path d="M12 44 Q30 30 50 40 Q60 44 68 40 L68 48 L12 48 Z" fill="#cdd9c2" />
      <path d="M12 48 Q28 38 44 44 Q58 49 68 44 L68 48 Z" fill="#d98f6a" />
    </g>
  ),
  recovery: (
    <g>
      <ellipse cx="40" cy="41" rx="25" ry="6" fill="#cdd9c2" />
      <line x1="22" y1="44" x2="31" y2="44" stroke="#e0cdbf" strokeWidth="1.4" strokeLinecap="round" />
      <line x1="49" y1="45" x2="58" y2="45" stroke="#e0cdbf" strokeWidth="1.4" strokeLinecap="round" />
      <path d="M28 33 Q40 23 52 33 Q40 41 28 33 Z" fill="#d98f6a" />
      <path d="M31 33 Q40 31 50 33" fill="none" stroke="#f2ead9" strokeWidth="1.4" strokeLinecap="round" />
    </g>
  ),
  learning: (
    <g>
      <path d="M40 26 Q29 20 15 23 L15 39 Q29 36 40 42 Q51 36 65 39 L65 23 Q51 20 40 26 Z" fill="#d98f6a" />
      <path d="M40 28 Q31 23 19 25 L19 38 Q31 36 40 41 Z" fill="#f2ead9" />
      <path d="M40 28 Q49 23 61 25 L61 38 Q49 36 40 41 Z" fill="#e0cdbf" />
      <line x1="24" y1="29" x2="36" y2="31" stroke="#cdd9c2" strokeWidth="1.4" strokeLinecap="round" />
      <line x1="24" y1="33" x2="36" y2="35" stroke="#cdd9c2" strokeWidth="1.4" strokeLinecap="round" />
      <line x1="44" y1="31" x2="56" y2="29" stroke="#e6a6a0" strokeWidth="1.4" strokeLinecap="round" />
      <line x1="44" y1="35" x2="56" y2="33" stroke="#e6a6a0" strokeWidth="1.4" strokeLinecap="round" />
    </g>
  ),
  aesthetic: (
    <g>
      <line x1="40" y1="26" x2="40" y2="45" stroke="#cdd9c2" strokeWidth="2.6" strokeLinecap="round" />
      <ellipse cx="46" cy="37" rx="5" ry="3" fill="#cdd9c2" transform="rotate(28 46 37)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(0 40 24)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(60 40 24)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(120 40 24)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(180 40 24)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(240 40 24)" />
      <ellipse cx="40" cy="17" rx="3.6" ry="6.2" fill="#e6a6a0" transform="rotate(300 40 24)" />
      <circle cx="40" cy="24" r="4.2" fill="#f0c891" />
    </g>
  )
};

// Humaaans — flat color-block figures.
const humaaansScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <circle cx="40" cy="16" r="6" fill="#e3b187" />
      <path d="M40 22 V36" stroke="#7d9a7a" strokeWidth="8" strokeLinecap="round" />
      <path d="M40 24 Q34 16 31 11 M40 24 Q46 16 49 11" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M37 36 V48 M43 36 V48" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
    </g>
  ),
  creation: (
    <g>
      <rect x="20" y="16" width="18" height="22" rx="2" fill="#cdd9c2" />
      <path d="M26 14 L29 44 M40 14 L37 44" stroke="#5e5448" strokeWidth="2.5" strokeLinecap="round" />
      <circle cx="54" cy="17" r="6" fill="#e3b187" />
      <path d="M54 23 V37" stroke="#6f8a6c" strokeWidth="8" strokeLinecap="round" />
      <path d="M54 26 Q46 27 39 27" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M51 37 V48 M57 37 V48" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
      <circle cx="29" cy="20" r="2.2" fill="#d98f6a" />
    </g>
  ),
  connection: (
    <g>
      <circle cx="31" cy="16" r="6" fill="#e3b187" />
      <path d="M31 22 V36" stroke="#7d9a7a" strokeWidth="8" strokeLinecap="round" />
      <path d="M28 36 V48 M34 36 V48" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
      <circle cx="49" cy="16" r="6" fill="#e3b187" />
      <path d="M49 22 V36" stroke="#6f8a6c" strokeWidth="8" strokeLinecap="round" />
      <path d="M46 36 V48 M52 36 V48" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
      <path d="M33 28 Q40 32 47 28" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
    </g>
  ),
  exploration: (
    <g>
      <circle cx="42" cy="16" r="6" fill="#e3b187" />
      <path d="M42 22 L40 35" stroke="#7d9a7a" strokeWidth="8" strokeLinecap="round" />
      <path d="M41 25 Q35 28 31 26 M41 25 Q47 27 51 31" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M40 35 L33 47 M40 35 L48 46" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
    </g>
  ),
  recovery: (
    <g>
      <circle cx="40" cy="18" r="6" fill="#e3b187" />
      <path d="M40 24 V36" stroke="#7d9a7a" strokeWidth="8" strokeLinecap="round" />
      <path d="M40 27 Q33 30 30 36 M40 27 Q47 30 50 36" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M40 36 Q33 38 31 44 M40 36 Q47 38 49 44" stroke="#5e5448" strokeWidth="4" fill="none" strokeLinecap="round" />
      <path d="M26 47 H54" stroke="#c9c4ba" strokeWidth="3" strokeLinecap="round" />
    </g>
  ),
  learning: (
    <g>
      <circle cx="40" cy="15" r="6" fill="#e3b187" />
      <path d="M40 21 V33" stroke="#6f8a6c" strokeWidth="8" strokeLinecap="round" />
      <path d="M40 25 Q34 28 31 34 M40 25 Q46 28 49 34" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M30 34 Q40 30 50 34 L50 44 Q40 40 30 44 Z" fill="#cdd9c2" stroke="#5e5448" strokeWidth="1.5" strokeLinejoin="round" />
      <path d="M40 32 V43" stroke="#5e5448" strokeWidth="1.5" strokeLinecap="round" />
    </g>
  ),
  aesthetic: (
    <g>
      <circle cx="40" cy="15" r="6" fill="#e3b187" />
      <path d="M40 21 V34" stroke="#7d9a7a" strokeWidth="8" strokeLinecap="round" />
      <path d="M40 25 Q34 29 36 34 M40 25 Q46 29 44 34" stroke="#e3b187" strokeWidth="3.5" fill="none" strokeLinecap="round" />
      <path d="M37 34 V46 M43 34 V46" stroke="#5e5448" strokeWidth="4" strokeLinecap="round" />
      <path d="M35 38 H45 L43 44 H37 Z" fill="#d98f6a" />
      <path d="M40 38 V31 M40 33 Q35 30 35 26 Q40 27 40 31 M40 33 Q45 30 45 26 Q40 27 40 31" fill="#7d9a7a" stroke="#6f8a6c" strokeWidth="1" />
    </g>
  )
};

// Open Peeps — loose ink line on a soft wash.
const openpeepsScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <ellipse cx="40" cy="30" rx="24" ry="17" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M25 31 Q40 45 55 31" />
        <path d="M23 31 H57" />
        <path d="M34 24 q-3 -5 0 -9" />
        <path d="M40 24 q-3 -5 0 -9" />
        <path d="M46 24 q-3 -5 0 -9" />
      </g>
    </g>
  ),
  creation: (
    <g>
      <ellipse cx="40" cy="29" rx="23" ry="16" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M28 42 L52 18" />
        <path d="M52 18 q3 -3 6 -1 q2 3 -1 6 L28 42 Z" />
        <path d="M28 42 l-3 5 l5 -2" />
        <path d="M22 22 q5 2 9 -1 q4 -3 9 0" />
      </g>
    </g>
  ),
  connection: (
    <g>
      <ellipse cx="40" cy="30" rx="24" ry="17" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="33" cy="22" r="4" />
        <path d="M33 26 q-6 2 -7 18 q4 2 9 1" />
        <circle cx="47" cy="22" r="4" />
        <path d="M47 26 q6 2 7 18 q-4 2 -9 1" />
        <path d="M36 31 q4 3 8 0" />
      </g>
    </g>
  ),
  exploration: (
    <g>
      <ellipse cx="40" cy="30" rx="24" ry="17" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M30 46 Q44 40 40 32 Q36 26 46 22 Q54 19 56 16" />
        <path d="M44 22 Q52 12 60 18" />
        <path d="M44 22 q3 1 5 0" />
      </g>
    </g>
  ),
  recovery: (
    <g>
      <ellipse cx="40" cy="30" rx="24" ry="17" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M32 26 Q40 16 50 22 Q46 32 34 30 Z" />
        <path d="M34 29 Q42 25 49 23" />
        <path d="M24 38 q5 -3 10 0 q5 3 10 0 q5 -3 10 0" />
        <path d="M26 43 q5 -3 10 0 q5 3 10 0 q5 -3 8 0" />
      </g>
    </g>
  ),
  learning: (
    <g>
      <ellipse cx="40" cy="30" rx="25" ry="16" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M40 22 Q30 17 20 20 L20 38 Q30 35 40 40 Q50 35 60 38 L60 20 Q50 17 40 22 Z" />
        <path d="M40 22 L40 40" />
        <path d="M25 25 q6 -2 11 0" />
        <path d="M25 30 q6 -2 11 0" />
        <path d="M44 25 q6 -2 11 0" />
        <path d="M44 30 q6 -2 11 0" />
      </g>
    </g>
  ),
  aesthetic: (
    <g>
      <ellipse cx="40" cy="29" rx="22" ry="17" fill="#ece4d6" />
      <g fill="none" stroke="#3a342c" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        <path d="M35 44 L33 32 L47 32 L45 44 Z" />
        <path d="M33 32 q7 3 14 0" />
        <path d="M40 32 L40 24" />
        <circle cx="40" cy="19" r="5" />
        <path d="M40 19 q-6 -1 -5 -7 q5 1 5 7" />
        <path d="M40 19 q6 -1 5 -7 q-5 1 -5 7" />
        <path d="M40 24 q-4 -1 -6 -4" />
      </g>
    </g>
  )
};

// unDraw — single-accent flat + greys.
const undrawScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <path d="M20 30 Q40 48 60 30 Z" fill="#7d9a7a" />
      <rect x="20" y="28" width="40" height="3" rx="1.5" fill="#c9c4ba" />
      <path d="M31 23 Q28 18 31 13" stroke="#b9b3a6" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M40 23 Q37 18 40 13" stroke="#b9b3a6" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M49 23 Q46 18 49 13" stroke="#b9b3a6" strokeWidth="2" strokeLinecap="round" fill="none" />
    </g>
  ),
  creation: (
    <g>
      <rect x="24" y="13" width="26" height="33" rx="2" fill="#dfdbd2" />
      <line x1="29" y1="21" x2="45" y2="21" stroke="#c9c4ba" strokeWidth="2" strokeLinecap="round" />
      <line x1="29" y1="27" x2="45" y2="27" stroke="#c9c4ba" strokeWidth="2" strokeLinecap="round" />
      <line x1="29" y1="33" x2="39" y2="33" stroke="#c9c4ba" strokeWidth="2" strokeLinecap="round" />
      <g transform="rotate(35 50 30)">
        <rect x="47.5" y="16" width="5" height="20" rx="1" fill="#7d9a7a" />
        <rect x="47.5" y="16" width="5" height="3" rx="1" fill="#9aab93" />
        <path d="M47.5 36 L52.5 36 L50 41 Z" fill="#b9b3a6" />
      </g>
    </g>
  ),
  connection: (
    <g>
      <circle cx="31" cy="22" r="6" fill="#7d9a7a" />
      <path d="M23 46 L23 36 Q23 30 31 30 Q39 30 39 36 L39 46 Z" fill="#7d9a7a" />
      <circle cx="49" cy="22" r="6" fill="#9aab93" />
      <path d="M41 46 L41 36 Q41 30 49 30 Q57 30 57 36 L57 46 Z" fill="#9aab93" />
    </g>
  ),
  exploration: (
    <g>
      <circle cx="50" cy="22" r="7" fill="#7d9a7a" />
      <path d="M12 44 Q26 30 40 40 Q54 50 68 36 L68 47 L12 47 Z" fill="#9aab93" />
      <path d="M12 46 Q28 37 44 44 Q58 50 68 42 L68 48 L12 48 Z" fill="#7d9a7a" />
    </g>
  ),
  recovery: (
    <g>
      <path d="M28 30 Q40 16 54 24 Q42 38 28 30 Z" fill="#7d9a7a" />
      <path d="M28 30 Q42 27 54 24" stroke="#9aab93" strokeWidth="1.5" strokeLinecap="round" fill="none" />
      <line x1="22" y1="39" x2="58" y2="39" stroke="#c9c4ba" strokeWidth="2" strokeLinecap="round" />
      <line x1="28" y1="44" x2="52" y2="44" stroke="#b9b3a6" strokeWidth="2" strokeLinecap="round" />
    </g>
  ),
  learning: (
    <g>
      <path d="M40 22 Q29 17 19 20 L19 41 Q29 38 40 43 Z" fill="#9aab93" />
      <path d="M40 22 Q51 17 61 20 L61 41 Q51 38 40 43 Z" fill="#7d9a7a" />
      <line x1="24" y1="26" x2="35" y2="27.5" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="24" y1="30" x2="35" y2="31.5" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="24" y1="34" x2="35" y2="35.5" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="45" y1="27.5" x2="56" y2="26" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="45" y1="31.5" x2="56" y2="30" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
      <line x1="45" y1="35.5" x2="56" y2="34" stroke="#dfdbd2" strokeWidth="1.5" strokeLinecap="round" />
    </g>
  ),
  aesthetic: (
    <g>
      <path d="M40 30 Q38 22 40 14" stroke="#7d9a7a" strokeWidth="2" strokeLinecap="round" fill="none" />
      <path d="M40 14 Q43 9 48 11 Q44 17 40 17 Z" fill="#7d9a7a" />
      <path d="M40 20 Q35 15 30 17 Q35 23 40 22 Z" fill="#9aab93" />
      <path d="M40 24 Q45 20 50 23 Q44 28 40 27 Z" fill="#9aab93" />
      <path d="M31 33 L49 33 L46 46 L34 46 Z" fill="#c9c4ba" />
      <rect x="30" y="30" width="20" height="4" rx="1" fill="#b9b3a6" />
    </g>
  )
};

// DrawKit — soft duotone on a gentle blob.
const drawkitScenes: Record<SeedCategory, ReactNode> = {
  body: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <path d="M26 30 q0 14 14 14 q14 0 14 -14 Z" fill="#9bb592" />
      <rect x="25" y="28" width="30" height="3.5" rx="1.75" fill="#5e7458" />
      <path d="M34 24 q-2.5 -4 0 -8 M44 24 q2.5 -4 0 -8" stroke="#5e7458" strokeWidth="2.4" fill="none" strokeLinecap="round" />
    </g>
  ),
  creation: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <rect x="26" y="16" width="22" height="28" rx="2.5" fill="#9bb592" />
      <line x1="31" y1="23" x2="42" y2="23" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="31" y1="28" x2="42" y2="28" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="31" y1="33" x2="38" y2="33" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
      <path d="M44 40 L54 22 L57 24 L47 42 Z" fill="#5e7458" />
      <path d="M44 40 L47 42 L43 44 Z" fill="#9bb592" />
    </g>
  ),
  connection: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <path d="M26 44 q0 -10 7 -10 q7 0 7 10 Z" fill="#9bb592" />
      <circle cx="33" cy="26" r="6" fill="#9bb592" />
      <path d="M40 44 q0 -12 8 -12 q8 0 8 12 Z" fill="#5e7458" />
      <circle cx="48" cy="24" r="6.5" fill="#5e7458" />
    </g>
  ),
  exploration: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <circle cx="48" cy="22" r="6" fill="#5e7458" />
      <path d="M14 44 q12 -16 26 -4 q12 10 26 4 L66 48 L14 48 Z" fill="#9bb592" />
      <path d="M14 44 q12 -16 26 -4 q12 10 26 4" stroke="#5e7458" strokeWidth="1.4" fill="none" strokeLinecap="round" />
    </g>
  ),
  recovery: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <path d="M30 28 q10 -10 20 0 q-10 10 -20 0 Z" fill="#9bb592" />
      <path d="M30 28 q10 -2 20 0" stroke="#5e7458" strokeWidth="1.6" fill="none" strokeLinecap="round" />
      <line x1="22" y1="38" x2="38" y2="38" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="44" y1="38" x2="58" y2="38" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
      <line x1="26" y1="43" x2="54" y2="43" stroke="#5e7458" strokeWidth="1.6" strokeLinecap="round" />
    </g>
  ),
  learning: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <path d="M40 20 q-12 -6 -24 -2 L16 40 q12 -4 24 2 Z" fill="#9bb592" />
      <path d="M40 20 q12 -6 24 -2 L64 40 q-12 -4 -24 2 Z" fill="#9bb592" />
      <line x1="40" y1="20" x2="40" y2="40" stroke="#5e7458" strokeWidth="2" strokeLinecap="round" />
      <path d="M22 26 q8 -2 14 1 M22 31 q8 -2 14 1 M44 27 q8 -3 14 -1 M44 32 q8 -3 14 -1" stroke="#5e7458" strokeWidth="1.3" fill="none" strokeLinecap="round" />
    </g>
  ),
  aesthetic: (
    <g>
      <ellipse cx="40" cy="30" rx="26" ry="19" fill="#dfe7d6" />
      <path d="M40 44 L40 26" stroke="#5e7458" strokeWidth="2.2" fill="none" strokeLinecap="round" />
      <path d="M40 30 q-10 -2 -12 -10 q10 0 12 10 Z" fill="#9bb592" />
      <path d="M40 26 q10 -3 12 -12 q-11 0 -12 12 Z" fill="#9bb592" />
      <path d="M40 30 q-10 -2 -12 -10 M40 26 q10 -3 12 -12" stroke="#5e7458" strokeWidth="1.3" fill="none" strokeLinecap="round" />
    </g>
  )
};

export const illustrationStyles: IllustrationStyle[] = [
  {
    key: "opendoodles",
    name: "Open Doodles",
    note: "手绘随性 · CC0",
    scene: (c) => opendoodlesScenes[c],
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
    scene: (c) => storysetScenes[c],
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
    scene: (c) => pixeltrueScenes[c],
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
    scene: (c) => blushScenes[c],
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
    scene: (c) => humaaansScenes[c],
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
    scene: (c) => openpeepsScenes[c],
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
    scene: (c) => undrawScenes[c],
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
    scene: (c) => drawkitScenes[c],
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
export function IllustrationArt({
  style,
  category,
  className,
}: {
  style: string;
  category?: SeedCategory;
  className?: string;
}) {
  const pack = illustrationStyles.find((s) => s.key === style) ?? illustrationStyles[0];
  return (
    <svg viewBox="0 0 80 56" className={className ?? "h-full w-full"} aria-hidden>
      {category && pack.scene ? pack.scene(category) : pack.art}
    </svg>
  );
}
