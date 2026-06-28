/**
 * The active Home "skin". The foundational core is shared; only the Home look
 * differs, chosen here by config (no branch, no code change). Selectable via
 * `NEXT_PUBLIC_AESTHETIC=glass|ocean|paper`. See docs/architecture-skins.md.
 */
export type Aesthetic = "glass" | "ocean" | "paper";

const VALID: readonly Aesthetic[] = ["glass", "ocean", "paper"];

export const AESTHETIC: Aesthetic = (VALID as readonly string[]).includes(
  process.env.NEXT_PUBLIC_AESTHETIC ?? ""
)
  ? (process.env.NEXT_PUBLIC_AESTHETIC as Aesthetic)
  : "glass";
