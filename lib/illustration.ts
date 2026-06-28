import type { SeedCategory } from "./types";

/**
 * Which category's illustration to show for a wish. A wish often has more than one
 * category (e.g. creation + learning); always drawing categories[0] makes two such
 * wishes look identical. Pick deterministically from the wish's own categories by a
 * stable hash of `key` (its id), so multi-category wishes spread across their looks
 * while staying stable per wish. Single-category wishes are unchanged.
 */
export function illustrationCategory(categories: SeedCategory[], key: string): SeedCategory {
  if (categories.length <= 1) return categories[0];
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
  return categories[h % categories.length];
}

/**
 * Pick a category for one wish in a set, preferring one not already used so a small
 * group (e.g. the 3 home cards) shows distinct illustrations. Falls back to the
 * hashed pick when every category is taken. Mutates `used`.
 */
export function distinctIllustrationCategory(
  categories: SeedCategory[],
  key: string,
  used: Set<SeedCategory>
): SeedCategory {
  const fresh = categories.find((c) => !used.has(c));
  const cat = fresh ?? illustrationCategory(categories, key);
  used.add(cat);
  return cat;
}
