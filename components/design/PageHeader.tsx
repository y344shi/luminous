export default function PageHeader({
  title,
  subtitle,
}: {
  title: string;
  subtitle?: string;
}) {
  return (
    <header className="px-1 pb-2 pt-2">
      <h1 className="text-[22px] font-semibold tracking-tight text-[var(--text)]">
        {title}
      </h1>
      {subtitle && (
        <p className="mt-1 whitespace-pre-line text-[14px] leading-relaxed text-[var(--text-secondary)]">
          {subtitle}
        </p>
      )}
    </header>
  );
}
