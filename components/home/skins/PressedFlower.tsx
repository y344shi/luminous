import type { SeedCategory } from "@core/types";

/**
 * A tiny pressed-flower mark for the paper skin — a faint botanical stamp that
 * varies by a wish's category, like a flower pressed into a notebook. Decorative
 * line-art; one motif per category.
 */
const marks: Record<SeedCategory, string> = {
  // a small sprig — two leaves on a stem
  body: "M12 22 V8 M12 14 C9 13 7.5 10.5 8 8 C10.5 8.5 12 10.5 12 13 M12 14 C15 13 16.5 10.5 16 8 C13.5 8.5 12 10.5 12 13",
  // a little bloom on a stem
  creation: "M12 21 V13 M12 13 C9 13 8 9.5 9 7 C11 8 12 10 12 12 C12 10 13 8 15 7 C16 9.5 15 13 12 13 Z",
  // a clover-heart — connection
  connection: "M12 18 V21 M12 13 C10 10 7 11 8 14 C9 16.5 12 18 12 18 C12 18 15 16.5 16 14 C17 11 14 10 12 13 Z",
  // a fern frond — exploration
  exploration: "M7 21 C9.5 15 12.5 9.5 18 6 M10 16 l3 -1 M11.5 13 l3 -1 M13.2 10 l3 -1",
  // a drooping bud — recovery / rest
  recovery: "M12 21 V11 M12 11 C12 8 14 6.8 16 8 C15 11 13 12 12 11",
  // a wheat sprig — learning
  learning: "M12 21 V7 M12 9.5 l3 -2 M12 9.5 l-3 -2 M12 12.5 l3 -2 M12 12.5 l-3 -2 M12 15.5 l3 -2 M12 15.5 l-3 -2",
  // a tulip — aesthetic
  aesthetic: "M12 21 V13 M12 13 C9 13 8 9 9 6 C11 7 12 9 12 11 C12 9 13 7 15 6 C16 9 15 13 12 13 Z",
};

export default function PressedFlower({
  category,
  className,
}: {
  category: SeedCategory;
  className?: string;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={26}
      height={26}
      fill="none"
      stroke="currentColor"
      strokeWidth={1.1}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
    >
      <path d={marks[category] ?? marks.aesthetic} />
    </svg>
  );
}
