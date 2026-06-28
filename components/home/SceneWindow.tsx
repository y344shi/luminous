import type { SceneKey } from "@/lib/ambient";

/**
 * The orb as a tiny living window: a small illustrated, gently animated world for
 * the sensed scene (desk / café / grass / highway / night / home / work / spark).
 * Pure SVG + CSS; animations respect prefers-reduced-motion (see globals.css).
 */
export default function SceneWindow({ icon }: { icon: SceneKey }) {
  return (
    <span className="scene-window" aria-hidden>
      <svg viewBox="0 0 100 100" width="100%" height="100%" preserveAspectRatio="xMidYMid slice">
        {scenes[icon] ?? scenes.spark}
      </svg>
    </span>
  );
}

const scenes: Record<SceneKey, React.ReactNode> = {
  night: (
    <>
      <rect width="100" height="100" fill="#2c2b48" />
      <circle cx="66" cy="34" r="11" fill="#e9e6ff" opacity="0.9" />
      <circle cx="60" cy="30" r="11" fill="#2c2b48" />
      <circle className="sw-twinkle" cx="24" cy="30" r="1.6" fill="#fff" />
      <circle className="sw-twinkle" style={{ animationDelay: "0.8s" }} cx="38" cy="20" r="1.2" fill="#fff" />
      <circle className="sw-twinkle" style={{ animationDelay: "1.5s" }} cx="30" cy="48" r="1.3" fill="#fff" />
    </>
  ),
  cafe: (
    <>
      <rect width="100" height="100" fill="#e7c79b" />
      <rect x="34" y="56" width="32" height="22" rx="5" fill="#7a5230" />
      <rect x="64" y="60" width="9" height="11" rx="4" fill="none" stroke="#7a5230" strokeWidth="3" />
      <path className="sw-steam" d="M44 50 q-4 -6 0 -12" stroke="#fff" strokeWidth="2.4" fill="none" opacity="0.7" />
      <path className="sw-steam" style={{ animationDelay: "1.1s" }} d="M56 50 q4 -6 0 -12" stroke="#fff" strokeWidth="2.4" fill="none" opacity="0.7" />
    </>
  ),
  grass: (
    <>
      <rect width="100" height="100" fill="#bfe0a0" />
      <circle cx="72" cy="28" r="12" fill="#ffe39a" />
      <ellipse cx="50" cy="98" rx="70" ry="34" fill="#9ccf7a" />
      <path className="sw-sway" d="M34 80 q2 -16 -2 -26" stroke="#6fae53" strokeWidth="3" fill="none" />
      <path className="sw-sway" style={{ animationDelay: "0.6s" }} d="M52 82 q-2 -18 2 -28" stroke="#6fae53" strokeWidth="3" fill="none" />
      <path className="sw-sway" style={{ animationDelay: "1.2s" }} d="M68 80 q2 -16 -2 -24" stroke="#6fae53" strokeWidth="3" fill="none" />
    </>
  ),
  desk: (
    <>
      <rect width="100" height="100" fill="#efe1c9" />
      <rect x="26" y="30" width="48" height="32" rx="3" fill="#5a5247" />
      <rect className="sw-glow" x="30" y="34" width="40" height="24" rx="2" fill="#cfe3ff" />
      <rect x="44" y="62" width="12" height="10" fill="#5a5247" />
      <rect x="34" y="72" width="32" height="4" rx="2" fill="#5a5247" />
    </>
  ),
  highway: (
    <>
      <rect width="100" height="100" fill="#b3a0d2" />
      <rect y="58" width="100" height="42" fill="#5a5280" />
      <polygon points="40,58 60,58 88,100 12,100" fill="#6b6396" />
      <g className="sw-dash">
        <rect x="47" y="62" width="6" height="9" fill="#ffe7b0" />
        <rect x="46" y="78" width="8" height="11" fill="#ffe7b0" />
      </g>
    </>
  ),
  home: (
    <>
      <rect width="100" height="100" fill="#f1d9cb" />
      <polygon points="50,26 80,52 20,52" fill="#c08562" />
      <rect x="28" y="52" width="44" height="40" fill="#d8a37e" />
      <rect className="sw-glow" x="42" y="62" width="16" height="20" rx="2" fill="#ffe6a8" />
    </>
  ),
  work: (
    <>
      <rect width="100" height="100" fill="#d6dde6" />
      <rect x="20" y="40" width="22" height="60" fill="#8b97a8" />
      <rect x="46" y="26" width="20" height="74" fill="#9aa6b7" />
      <rect x="70" y="50" width="16" height="50" fill="#8b97a8" />
      <rect className="sw-glow" x="50" y="34" width="5" height="6" fill="#fff3c4" />
      <rect className="sw-glow" style={{ animationDelay: "1s" }} x="58" y="46" width="5" height="6" fill="#fff3c4" />
    </>
  ),
  spark: (
    <>
      <rect width="100" height="100" fill="#efe7da" />
      <g fill="#e8c37a">
        <circle className="sw-twinkle" cx="34" cy="40" r="3" />
        <circle className="sw-twinkle" style={{ animationDelay: "0.7s" }} cx="62" cy="32" r="2.4" />
        <circle className="sw-twinkle" style={{ animationDelay: "1.3s" }} cx="54" cy="62" r="2.8" />
        <circle className="sw-twinkle" style={{ animationDelay: "1.9s" }} cx="40" cy="66" r="2" />
      </g>
    </>
  ),
};
