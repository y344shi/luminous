export default function EmptyState({
  text,
  hint,
}: {
  text: string;
  hint?: string;
}) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-12 text-center">
      <div className="mb-1 h-10 w-10 rounded-full bg-[var(--accent-soft)]" />
      <p className="whitespace-pre-line text-[15px] leading-relaxed text-[var(--text-secondary)]">
        {text}
      </p>
      {hint && <p className="text-[13px] text-[var(--text-muted)]">{hint}</p>}
    </div>
  );
}
