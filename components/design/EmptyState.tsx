import Link from "next/link";

type Action = { label: string; href: string };

export default function EmptyState({
  text,
  hint,
  icon,
  action,
}: {
  text: string;
  hint?: string;
  /** A small emoji or glyph centered in the breathing mark. */
  icon?: string;
  /** Optional gentle next step (never a command — an invitation). */
  action?: Action;
}) {
  return (
    <div className="tdd-rise flex flex-col items-center gap-3 px-6 py-12 text-center">
      <div className="relative mb-1 flex h-16 w-16 items-center justify-center">
        <span className="tdd-pulse absolute inset-0 rounded-full bg-[var(--accent-soft)]" />
        <span className="relative text-2xl" aria-hidden>
          {icon ?? ""}
        </span>
      </div>
      <p className="whitespace-pre-line text-[15px] leading-relaxed text-[var(--text-secondary)]">
        {text}
      </p>
      {hint && <p className="text-[13px] text-[var(--text-muted)]">{hint}</p>}
      {action && (
        <Link
          href={action.href}
          className="mt-2 rounded-full bg-[var(--accent-soft)] px-5 py-2.5 text-[14px] text-[var(--text)] transition-all active:scale-[0.98]"
        >
          {action.label}
        </Link>
      )}
    </div>
  );
}
