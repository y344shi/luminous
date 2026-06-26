/**
 * Inline SVG filter defs for the liquid-glass refraction. `#tdd-liquid` warps a
 * translucent highlight layer inside each bubble (via `.glass-refract`) with slow
 * fractal turbulence + displacement, so the light caustics drift like real glass.
 * Rendered once; referenced by id from CSS.
 */
export default function GlassFilters() {
  return (
    <svg aria-hidden width="0" height="0" style={{ position: "absolute" }}>
      <defs>
        <filter id="tdd-liquid" x="-30%" y="-30%" width="160%" height="160%">
          <feTurbulence type="fractalNoise" baseFrequency="0.012 0.016" numOctaves="2" seed="7" result="noise">
            <animate
              attributeName="baseFrequency"
              dur="26s"
              values="0.011 0.015; 0.016 0.011; 0.011 0.015"
              repeatCount="indefinite"
            />
          </feTurbulence>
          <feGaussianBlur in="noise" stdDeviation="0.5" result="soft" />
          <feDisplacementMap
            in="SourceGraphic"
            in2="soft"
            scale="16"
            xChannelSelector="R"
            yChannelSelector="G"
          />
        </filter>
      </defs>
    </svg>
  );
}
