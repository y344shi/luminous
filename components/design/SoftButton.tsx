"use client";

import { cx } from "@/lib/utils";

type Variant = "primary" | "soft" | "ghost";

type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  full?: boolean;
};

const base =
  "inline-flex items-center justify-center rounded-full font-medium select-none " +
  "transition-all duration-300 active:scale-[0.98] disabled:opacity-50 disabled:pointer-events-none " +
  "px-6 py-3 text-[15px] leading-none focus:outline-none";

const variants: Record<Variant, string> = {
  primary:
    "bg-[var(--accent)] text-[var(--on-accent)] shadow-[var(--shadow-card)] hover:brightness-105",
  soft:
    "bg-[var(--accent-soft)] text-[var(--text)] hover:brightness-[0.98]",
  ghost:
    "bg-transparent text-[var(--text-secondary)] hover:bg-[var(--surface-soft)]",
};

export default function SoftButton({
  variant = "primary",
  full,
  className,
  children,
  ...rest
}: Props) {
  return (
    <button
      className={cx(base, variants[variant], full && "w-full", className)}
      {...rest}
    >
      {children}
    </button>
  );
}
